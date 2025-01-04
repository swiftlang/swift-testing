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
#include <atomic>
#include <cstring>
#include <iterator>
#include <tuple>
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

/// Enumerate over all Swift type metadata sections in the current process.
///
/// - Parameters:
///   - body: A function to call once for every section in the current process.
///     A pointer to the first type metadata record and the number of records
///     are passed to this function.
template <typename SectionEnumerator>
static void enumerateTypeMetadataSections(const SectionEnumerator& body);

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
///
/// The template argument `T` is the element type of the metadata section.
/// Instances of this type can be used with a range-based `for`-loop to iterate
/// the contents of the section.
template <typename T>
struct SWTSectionBounds {
  /// The base address of the image containing the section, if known.
  const void *imageAddress;

  /// The base address of the section.
  const void *start;

  /// The size of the section in bytes.
  size_t size;

  const struct SWTTypeMetadataRecord *begin(void) const {
    return reinterpret_cast<const T *>(start);
  }

  const struct SWTTypeMetadataRecord *end(void) const {
    return reinterpret_cast<const T *>(reinterpret_cast<uintptr_t>(start) + size);
  }
};

/// A type that acts as a C++ [Container](https://en.cppreference.com/w/cpp/named_req/Container)
/// and which contains a sequence of instances of `SWTSectionBounds<T>`.
template <typename T>
using SWTSectionBoundsList = std::vector<SWTSectionBounds<T>, SWTHeapAllocator<SWTSectionBounds<T>>>;

#pragma mark - Swift ABI

#if defined(__PTRAUTH_INTRINSICS__)
#include <ptrauth.h>
#define SWT_PTRAUTH __ptrauth
#else
#define SWT_PTRAUTH(...)
#endif
#define SWT_PTRAUTH_SWIFT_TYPE_DESCRIPTOR SWT_PTRAUTH(ptrauth_key_process_independent_data, 1, 0xae86)

/// A type representing a pointer relative to itself.
///
/// This type is derived from `RelativeDirectPointerIntPair` in the Swift
/// repository.
template <typename T, int32_t maskValue = 0>
struct SWTRelativePointer {
private:
  int32_t _offset;

public:
  SWTRelativePointer(const SWTRelativePointer&) = delete;
  SWTRelativePointer(const SWTRelativePointer&&) = delete;
  SWTRelativePointer& operator =(const SWTRelativePointer&) = delete;
  SWTRelativePointer& operator =(const SWTRelativePointer&&) = delete;

  int32_t getRawValue(void) const {
    return _offset;
  }

  const T *_Nullable get(void) const& {
    int32_t maskedOffset = getRawValue() & ~maskValue;
    if (maskedOffset == 0) {
      return nullptr;
    }

    auto offset = static_cast<uintptr_t>(static_cast<intptr_t>(maskedOffset));
    auto result = reinterpret_cast<void *>(reinterpret_cast<uintptr_t>(this) + offset);
#if defined(__PTRAUTH_INTRINSICS__)
    if (std::is_function_v<T> && result) {
      result = ptrauth_strip(result, ptrauth_key_function_pointer);
      result = ptrauth_sign_unauthenticated(result, ptrauth_key_function_pointer, 0);
    }
#endif
    return reinterpret_cast<const T *>(result);
  }

  const T *_Nullable operator ->(void) const& {
    return get();
  }
};

/// A type representing a 32-bit absolute function pointer, usually used on platforms
/// where relative function pointers are not supported.
///
/// This type is derived from `AbsoluteFunctionPointer` in the Swift repository.
template <typename T>
struct SWTAbsoluteFunctionPointer {
private:
  T *_pointer;
  static_assert(sizeof(T *) == sizeof(int32_t), "Function pointer must be 32-bit when using compact absolute pointer");

public:
  const T *_Nullable get(void) const & {
    return _pointer;
  }

  const T *_Nullable operator ->(void) const & {
    return get();
  }
};

/// A type representing a pointer relative to itself with low bits reserved for
/// use as flags.
///
/// This type is derived from `RelativeDirectPointerIntPair` in the Swift
/// repository.
template <typename T, typename I, int32_t maskValue = (alignof(int32_t) - 1)>
struct SWTRelativePointerIntPair: public SWTRelativePointer<T, maskValue> {
  I getInt() const & {
    return I(this->getRawValue() & maskValue);
  }
};

template <typename T>
#if defined(__wasm32__)
using SWTCompactFunctionPointer = SWTAbsoluteFunctionPointer<T>;
#else
using SWTCompactFunctionPointer = SWTRelativePointer<T>;
#endif

/// A type representing a metatype as constructed during compilation of a Swift
/// module.
///
/// This type is derived from `TargetTypeContextDescriptor` in the Swift
/// repository.
struct SWTTypeContextDescriptor {
private:
  uint32_t _flags;
  SWTRelativePointer<void> _parent;
  SWTRelativePointer<char> _name;

  struct MetadataAccessResponse {
    void *value;
    size_t state;
  };
  using MetadataAccessFunction = __attribute__((swiftcall)) MetadataAccessResponse(size_t);
  SWTCompactFunctionPointer<MetadataAccessFunction> _metadataAccessFunction;

public:
  const char *_Nullable getName(void) const& {
    return _name.get();
  }

  void *_Nullable getMetadata(void) const& {
    if (auto fp = _metadataAccessFunction.get()) {
      return (* fp)(0xFF).value;
    }
    return nullptr;
  }

  bool isGeneric(void) const& {
    return (_flags & 0x80u) != 0;
  }
};

/// A type representing a relative pointer to a type descriptor.
///
/// This type is derived from `TargetTypeMetadataRecord` in the Swift
/// repository.
struct SWTTypeMetadataRecord {
private:
  SWTRelativePointerIntPair<void, unsigned int> _pointer;

public:
  const SWTTypeContextDescriptor *_Nullable getContextDescriptor(void) const {
    switch (_pointer.getInt()) {
    case 0: // Direct pointer.
      return reinterpret_cast<const SWTTypeContextDescriptor *>(_pointer.get());
    case 1: // Indirect pointer (pointer to a pointer.)
            // The inner pointer is signed when pointer authentication
            // instructions are available.
      if (auto contextDescriptor = reinterpret_cast<SWTTypeContextDescriptor *const SWT_PTRAUTH_SWIFT_TYPE_DESCRIPTOR *>(_pointer.get())) {
        return *contextDescriptor;
      }
      [[fallthrough]];
    default: // Unsupported or invalid.
      return nullptr;
    }
  }
};

#if !defined(SWT_NO_DYNAMIC_LINKING)
#if defined(__APPLE__)
#pragma mark - Apple implementation

/// Get a copy of the currently-loaded type metadata sections list.
///
/// - Returns: A list of type metadata sections in images loaded into the
///   current process. The order of the resulting list is unspecified.
///
/// On ELF-based platforms, the `swift_enumerateAllMetadataSections()` function
/// exported by the runtime serves the same purpose as this function.
static SWTSectionBoundsList<SWTTypeMetadataRecord> getSectionBounds(void) {
  /// This list is necessarily mutated while a global libobjc- or dyld-owned
  /// lock is held. Hence, code using this list must avoid potentially
  /// re-entering either library (otherwise it could potentially deadlock.)
  ///
  /// To see how the Swift runtime accomplishes the above goal, see
  /// `ConcurrentReadableArray` in that project's Concurrent.h header. Since the
  /// testing library is not tasked with the same performance constraints as
  /// Swift's runtime library, we just use a `std::vector` guarded by an unfair
  /// lock.
  static constinit SWTSectionBoundsList<SWTTypeMetadataRecord> *sectionBounds = nullptr;
  static constinit os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

  static constinit dispatch_once_t once = 0;
  dispatch_once_f(&once, nullptr, [] (void *) {
    sectionBounds = reinterpret_cast<SWTSectionBoundsList<SWTTypeMetadataRecord> *>(std::malloc(sizeof(SWTSectionBoundsList<SWTTypeMetadataRecord>)));
    ::new (sectionBounds) SWTSectionBoundsList<SWTTypeMetadataRecord>();
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
      auto start = getsectiondata(mhn, SEG_TEXT, "__swift5_types", &size);
      if (start && size > 0) {
        os_unfair_lock_lock(&lock); {
          sectionBounds->emplace_back(mhn, start, size);
        } os_unfair_lock_unlock(&lock);
      }
    });
  });

  // After the first call sets up the loader hook, all calls take the lock and
  // make a copy of whatever has been loaded so far.
  SWTSectionBoundsList<SWTTypeMetadataRecord> result;
  result.reserve(_dyld_image_count());
  os_unfair_lock_lock(&lock); {
    result = *sectionBounds;
  } os_unfair_lock_unlock(&lock);
  result.shrink_to_fit();
  return result;
}

template <typename SectionEnumerator>
static void enumerateTypeMetadataSections(const SectionEnumerator& body) {
  bool stop = false;
  for (const auto& sb : getSectionBounds()) {
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
static std::optional<SWTSectionBounds<SWTTypeMetadataRecord>> findSection(HMODULE hModule, const char *sectionName) {
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

    auto start = reinterpret_cast<const void *>(reinterpret_cast<uintptr_t>(dosHeader) + section->VirtualAddress);
    size_t size = std::min(section->Misc.VirtualSize, section->SizeOfRawData);
    if (start && size > 0) {
      // FIXME: Handle longer names ("/%u") from string table
      auto thisSectionName = reinterpret_cast<const char *>(section->Name);
      if (0 == std::strncmp(sectionName, thisSectionName, IMAGE_SIZEOF_SHORT_NAME)) {
        return SWTSectionBounds<SWTTypeMetadataRecord> { hModule, start, size };
      }
    }
  }

  return std::nullopt;
}

template <typename SectionEnumerator>
static void enumerateTypeMetadataSections(const SectionEnumerator& body) {
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
  SWTSectionBoundsList<SWTTypeMetadataRecord> sectionBounds;
  sectionBounds.reserve(hModuleCount);
  for (size_t i = 0; i < hModuleCount; i++) {
    if (auto sb = findSection(hModules[i], ".sw5tymd")) {
      sectionBounds.push_back(*sb);
    }
  }

  // Pass each discovered section back to the body callback.
  //
  // NOTE: we ignore the leading and trailing uintptr_t values: they're both
  // always set to zero so we'll skip them in the callback, and in the future
  // the toolchain might not emit them at all in which case we don't want to
  // skip over real section data.
  bool stop = false;
  for (const auto& sb : sectionBounds) {
    body(sb, &stop);
    if (stop) {
      break;
    }
  }
}

#elif defined(__linux__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__ANDROID__)
#pragma mark - ELF implementation

/// Specifies the address range corresponding to a section.
struct MetadataSectionRange {
  uintptr_t start;
  size_t length;
};

/// Identifies the address space ranges for the Swift metadata required by the
/// Swift runtime.
struct MetadataSections {
  uintptr_t version;
  std::atomic<const void *> baseAddress;

  void *unused0;
  void *unused1;

  MetadataSectionRange swift5_protocols;
  MetadataSectionRange swift5_protocol_conformances;
  MetadataSectionRange swift5_type_metadata;
  MetadataSectionRange swift5_typeref;
  MetadataSectionRange swift5_reflstr;
  MetadataSectionRange swift5_fieldmd;
  MetadataSectionRange swift5_assocty;
  MetadataSectionRange swift5_replace;
  MetadataSectionRange swift5_replac2;
  MetadataSectionRange swift5_builtin;
  MetadataSectionRange swift5_capture;
  MetadataSectionRange swift5_mpenum;
  MetadataSectionRange swift5_accessible_functions;
};

/// A function exported by the Swift runtime that enumerates all metadata
/// sections loaded into the current process.
SWT_IMPORT_FROM_STDLIB void swift_enumerateAllMetadataSections(
  bool (* body)(const MetadataSections *sections, void *context),
  void *context
);

template <typename SectionEnumerator>
static void enumerateTypeMetadataSections(const SectionEnumerator& body) {
  swift_enumerateAllMetadataSections([] (const MetadataSections *sections, void *context) {
    bool stop = false;

    const auto& body = *reinterpret_cast<const SectionEnumerator *>(context);
    MetadataSectionRange section = sections->swift5_type_metadata;
    if (section.start && section.length > 0) {
      SWTSectionBounds<SWTTypeMetadataRecord> sb = {
        sections->baseAddress.load(),
        reinterpret_cast<const void *>(section.start),
        section.length
      };
      body(sb, &stop);
    }

    return !stop;
  }, const_cast<SectionEnumerator *>(&body));
}
#else
#warning Platform-specific implementation missing: Runtime test discovery unavailable (dynamic)
template <typename SectionEnumerator>
static void enumerateTypeMetadataSections(const SectionEnumerator& body) {}
#endif

#else
#pragma mark - Statically-linked implementation

#if defined(__APPLE__)
extern "C" const char sectionBegin __asm__("section$start$__TEXT$__swift5_types");
extern "C" const char sectionEnd __asm__("section$end$__TEXT$__swift5_types");
#elif defined(__wasi__)
extern "C" const char sectionBegin __asm__("__start_swift5_type_metadata");
extern "C" const char sectionEnd __asm__("__stop_swift5_type_metadata");
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

void swt_enumerateTypesWithNamesContaining(const char *nameSubstring, void *context, SWTTypeEnumerator body) {
  enumerateTypeMetadataSections([=] (const SWTSectionBounds<SWTTypeMetadataRecord>& sectionBounds, bool *stop) {
    for (const auto& record : sectionBounds) {
      auto contextDescriptor = record.getContextDescriptor();
      if (!contextDescriptor) {
        // This type metadata record is invalid (or we don't understand how to
        // get its context descriptor), so skip it.
        continue;
      } else if (contextDescriptor->isGeneric()) {
        // Generic types cannot be fully instantiated without generic
        // parameters, which is not something we can know abstractly.
        continue;
      }

      // Check that the type's name passes. This will be more expensive than the
      // checks above, but should be cheaper than realizing the metadata.
      const char *typeName = contextDescriptor->getName();
      bool nameOK = typeName && nullptr != std::strstr(typeName, nameSubstring);
      if (!nameOK) {
        continue;
      }

      if (void *typeMetadata = contextDescriptor->getMetadata()) {
        body(sectionBounds.imageAddress, typeMetadata, stop, context);
      }
    }
  });
}
