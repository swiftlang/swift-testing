//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#include "Discovery.h"

#include <algorithm>
#include <array>
#include <cassert>
#include <cstring>
#include <string_view>
#include <type_traits>
#include <vector>
#include <optional>

#if defined(__APPLE__) && !defined(SWT_NO_DYNAMIC_LINKING)
#include <dispatch/dispatch.h>
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <objc/runtime.h>
#include <os/lock.h>
#endif

/// Enumerate over all Swift test content sections in the current process.
///
/// - Parameters:
///   - body: A function to call once for every section in the current process
///     that contains test content. A pointer to the first test content record
///     and the size, in bytes, of the section are passed to this function.
template <typename SectionEnumerator>
static void enumerateTestContentSections(const SectionEnumerator& body);

/// A type that acts as a C++ [Allocator](https://en.cppreference.com/w/cpp/named_req/Allocator)
/// without using global `operator new` or `operator delete`.
///
/// This type is necessary because global `operator new` and `operator delete`
/// can be overridden in developer-supplied code and cause deadlocks or crashes
/// when subsequently used while holding a dyld- or libobjc-owned lock. Using
/// `std::malloc()` and `std::free()` allows the use of C++ container types
/// without this risk.
template<typename T>
struct SWTHeapAllocator {
  using value_type = T;

  T *allocate(size_t count) {
    return reinterpret_cast<T *>(std::calloc(count, sizeof(T)));
  }

  void deallocate(T *ptr, size_t count) {
    std::free(ptr);
  }
};

/// A structure describing the bounds of a Swift metadata section.
struct SWTSectionBounds {
  /// The base address of the image containing the section, if known.
  const void *imageAddress;

  /// The base address of the section.
  const void *start;

  /// The size of the section in bytes.
  size_t size;
};

/// A type that acts as a C++ [Container](https://en.cppreference.com/w/cpp/named_req/Container)
/// and which contains a sequence of instances of `SWTSectionBounds`.
using SWTSectionBoundsList = std::vector<SWTSectionBounds, SWTHeapAllocator<SWTSectionBounds>>;

#if !defined(SWT_NO_DYNAMIC_LINKING)
#if defined(__APPLE__)
#pragma mark - Apple implementation

static SWTSectionBoundsList getTestContentSections(void) {
  /// This list is necessarily mutated while a global libobjc- or dyld-owned
  /// lock is held. Hence, code using this list must avoid potentially
  /// re-entering either library (otherwise it could potentially deadlock.)
  ///
  /// To see how the Swift runtime accomplishes the above goal, see
  /// `ConcurrentReadableArray` in that project's Concurrent.h header. Since the
  /// testing library is not tasked with the same performance constraints as
  /// Swift's runtime library, we just use a `std::vector` guarded by an unfair
  /// lock.
  static constinit SWTSectionBoundsList *sectionBounds = nullptr;
  static constinit os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

  static constinit dispatch_once_t once = 0;
  dispatch_once_f(&once, nullptr, [] (void *) {
    sectionBounds = reinterpret_cast<SWTSectionBoundsList *>(std::malloc(sizeof(SWTSectionBoundsList)));
    ::new (sectionBounds) SWTSectionBoundsList();
    sectionBounds->reserve(_dyld_image_count());

    objc_addLoadImageFunc([] (const mach_header *mh) {
#if __LP64__
      auto mhn = reinterpret_cast<const mach_header_64 *>(mh);
#else
      auto mhn = mh;
#endif

      // Ignore this Mach header if it is in the shared cache. On platforms that
      // support it (Darwin), most system images are contained in this range.
      // System images can be expected not to contain test declarations, so we
      // don't need to walk them.
      if (mhn->flags & MH_DYLIB_IN_CACHE) {
        return;
      }

      // If this image contains the Swift section we need, acquire the lock and
      // store the section's bounds.
      unsigned long size = 0;
      auto start = getsectiondata(mhn, "__DATA_CONST", "__swift5_tests", &size);
      if (start && size > 0) {
        os_unfair_lock_lock(&lock); {
          sectionBounds->emplace_back(mhn, start, size);
        } os_unfair_lock_unlock(&lock);
      }
    });
  });

  // After the first call sets up the loader hook, all calls take the lock and
  // make a copy of whatever has been loaded so far.
  SWTSectionBoundsList result;
  result.reserve(_dyld_image_count());
  os_unfair_lock_lock(&lock); {
    result = *sectionBounds;
  } os_unfair_lock_unlock(&lock);
  result.shrink_to_fit();
  return result;
}

template <typename SectionEnumerator>
static void enumerateTestContentSections(const SectionEnumerator& body) {
  bool stop = false;
  for (const auto& sb : getTestContentSections()) {
    body(sb, &stop);
    if (stop) {
      break;
    }
  }
}

#elif defined(_WIN32)
#pragma mark - Windows implementation

/// Find the section with the given name in the given module.
///
/// - Parameters:
///   - hModule: The module to inspect.
///   - sectionName: The name of the section to look for. Long section names are
///     not supported.
///
/// - Returns: A pointer to the start of the given section along with its size
///   in bytes, or `std::nullopt` if the section could not be found. If the
///   section was emitted by the Swift toolchain, be aware it will have leading
///   and trailing bytes (`sizeof(uintptr_t)` each.)
static std::optional<SWTSectionBounds> findSection(HMODULE hModule, const char *sectionName) {
  if (!hModule) {
    return std::nullopt;
  }

  // Get the DOS header (to which the HMODULE directly points, conveniently!)
  // and check it's sufficiently valid for us to walk.
  auto dosHeader = reinterpret_cast<const PIMAGE_DOS_HEADER>(hModule);
  if (dosHeader->e_magic != IMAGE_DOS_SIGNATURE || dosHeader->e_lfanew <= 0) {
    return std::nullopt;
  }

  // Check the NT header. Since we don't use the optional header, skip it.
  auto ntHeader = reinterpret_cast<const PIMAGE_NT_HEADERS>(reinterpret_cast<uintptr_t>(dosHeader) + dosHeader->e_lfanew);
  if (!ntHeader || ntHeader->Signature != IMAGE_NT_SIGNATURE) {
    return std::nullopt;
  }

  auto sectionCount = ntHeader->FileHeader.NumberOfSections;
  auto section = IMAGE_FIRST_SECTION(ntHeader);
  for (size_t i = 0; i < sectionCount; i++, section += 1) {
    if (section->VirtualAddress == 0) {
      continue;
    }

    auto start = reinterpret_cast<const char *>(reinterpret_cast<uintptr_t>(dosHeader) + section->VirtualAddress);
    size_t size = std::min(section->Misc.VirtualSize, section->SizeOfRawData);
    if (start && size > 0) {
      // FIXME: Handle longer names ("/%u") from string table
      auto thisSectionName = reinterpret_cast<const char *>(section->Name);
      if (0 == std::strncmp(sectionName, thisSectionName, IMAGE_SIZEOF_SHORT_NAME)) {
        // Skip over the leading and trailing zeroed uintptr_t values. These
        // values are always emitted by SwiftRT-COFF.cpp into all Swift images.
#if DEBUG
        assert(size >= (2 * sizeof(uintptr_t)));
        uintptr_t firstPointerValue = 0;
        memcpy(&firstPointerValue, start, sizeof(uintptr_t));
        assert(firstPointerValue == 0);
        uintptr_t lastPointerValue = 0;
        memcpy(&lastPointerValue, (start + size) - sizeof(uintptr_t), sizeof(uintptr_t));
        assert(lastPointerValue == 0);
#endif
        if (size > 2 * sizeof(uintptr_t)) {
          return SWTSectionBounds { hModule, start + sizeof(uintptr_t), size - (2 * sizeof(uintptr_t)) };
        }
      }
    }
  }

  return std::nullopt;
}

template <typename SectionEnumerator>
static void enumerateTestContentSections(const SectionEnumerator& body) {
  // Find all the modules loaded in the current process. We assume there aren't
  // more than 1024 loaded modules (as does Microsoft sample code.)
  std::array<HMODULE, 1024> hModules;
  DWORD byteCountNeeded = 0;
  if (!EnumProcessModules(GetCurrentProcess(), &hModules[0], hModules.size() * sizeof(HMODULE), &byteCountNeeded)) {
    return;
  }
  size_t hModuleCount = std::min(hModules.size(), static_cast<size_t>(byteCountNeeded) / sizeof(HMODULE));

  // Look in all the loaded modules for Swift type metadata sections and store
  // them in a side table.
  //
  // This two-step process is more complicated to read than a single loop would
  // be but it is safer: the callback will eventually invoke developer code that
  // could theoretically unload a module from the list we're enumerating. (Swift
  // modules do not support unloading, so we'll just not worry about them.)
  SWTSectionBoundsList sectionBounds;
  sectionBounds.reserve(hModuleCount);
  for (size_t i = 0; i < hModuleCount; i++) {
    if (auto sb = findSection(hModules[i], ".sw5test")) {
      sectionBounds.push_back(*sb);
    }
  }

  // Pass each discovered section back to the body callback.
  bool stop = false;
  for (const auto& sb : sectionBounds) {
    body(sb, &stop);
    if (stop) {
      break;
    }
  }
}

#elif defined(__linux__) || defined(__FreeBSD__) || defined(__ANDROID__)
#pragma mark - ELF implementation

template <typename SectionEnumerator>
static void enumerateTestContentSections(const SectionEnumerator& body) {
  dl_iterate_phdr([] (struct dl_phdr_info *info, size_t size, void *context) -> int {
    const auto& body = *reinterpret_cast<SectionEnumerator *>(context);

    bool stop = false;
    for (size_t i = 0; !stop && i < info->dlpi_phnum; i++) {
      const auto& phdr = info->dlpi_phdr[i];
      if (phdr.p_type == PT_NOTE) {
        SWTSectionBounds sb = {
          reinterpret_cast<const void *>(info->dlpi_addr),
          reinterpret_cast<const void *>(info->dlpi_addr + phdr.p_vaddr),
          static_cast<size_t>(phdr.p_memsz)
        };
        body(sb, &stop);
      }
    }

    return stop;
  }, const_cast<SectionEnumerator *>(&body));
}
#else
#warning Platform-specific implementation missing: Runtime test discovery unavailable (dynamic)
template <typename SectionEnumerator>
static void enumerateTestContentSections(const SectionEnumerator& body) {}
#endif

#else
#pragma mark - Statically-linked implementation

#if defined(__APPLE__)
extern "C" const char sectionBegin __asm("section$start$__DATA_CONST$__swift5_tests");
extern "C" const char sectionEnd __asm("section$end$__DATA_CONST$__swift5_tests");
#elif defined(__wasi__)
extern "C" const char sectionBegin __asm__("__start_swift5_tests");
extern "C" const char sectionEnd __asm__("__stop_swift5_tests");
#else
#warning Platform-specific implementation missing: Runtime test discovery unavailable (static)
static const char sectionBegin = 0;
static const char& sectionEnd = sectionBegin;
#endif

template <typename SectionEnumerator>
static void enumerateTypeMetadataSections(const SectionEnumerator& body) {
  SWTSectionBounds<SWTTypeMetadataRecord> sb = {
    nullptr,
    &sectionBegin,
    static_cast<size_t>(std::distance(&sectionBegin, &sectionEnd))
  };
  bool stop = false;
  body(sb, &stop);
}
#endif

#pragma mark -

void swt_enumerateTestContent(void *context, SWTTestContentEnumerator body) {
  enumerateTestContentSections([=] (const SWTSectionBounds& sb, bool *stop) {
    auto next = [] (const SWTTestContentHeader *header) -> const SWTTestContentHeader * {
      auto size = __builtin_align_up(
        sizeof(*header) + __builtin_align_up(header->n_namesz, alignof(uint32_t)) + header->n_descsz,
        alignof(uintptr_t)
      );
      return reinterpret_cast<const SWTTestContentHeader *>(reinterpret_cast<uintptr_t>(header) + size);
    };

    // Because the size of a test content record is not fixed, walking a test
    // content section isn't particularly elegant. (Sorry!)
    auto header = reinterpret_cast<const SWTTestContentHeader *>(sb.start);
    auto end = reinterpret_cast<uintptr_t>(sb.start) + sb.size;
    for (; reinterpret_cast<uintptr_t>(header) < end; header = next(header)) {
      body(sb.imageAddress, header, stop, context);
    }
  });
}
