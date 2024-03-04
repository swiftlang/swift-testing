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

#include <atomic>
#include <iterator>
#include <type_traits>
#include <vector>

#if defined(SWT_NO_DYNAMIC_LINKING)
#include <algorithm>
#elif defined(__APPLE__)
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
  SWTRelativePointer<MetadataAccessFunction> _metadataAccessFunction;

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

#if defined(SWT_NO_DYNAMIC_LINKING)
#pragma mark - Statically-linked implementation

// This environment does not have a dynamic linker/loader. Therefore, there is
// only one image (this one) with Swift code in it.
// SEE: https://github.com/apple/swift/tree/main/stdlib/public/runtime/ImageInspectionStatic.cpp

extern "C" const char sectionBegin __asm("section$start$__TEXT$__swift5_types");
extern "C" const char sectionEnd __asm("section$end$__TEXT$__swift5_types");

template <typename SectionEnumerator>
static void enumerateTypeMetadataSections(const SectionEnumerator& body) {
  auto size = std::distance(&sectionBegin, &sectionEnd);
  body(&sectionBegin, size);
}

#elif defined(__APPLE__)
#pragma mark - Apple implementation

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

/// A type that acts as a C++ [Container](https://en.cppreference.com/w/cpp/named_req/Container)
/// and which contains a sequence of Mach headers.
#if __LP64__
using SWTMachHeaderList = std::vector<const mach_header_64 *, SWTHeapAllocator<const mach_header_64 *>>;
#else
using SWTMachHeaderList = std::vector<const mach_header *, SWTHeapAllocator<const mach_header *>>;
#endif

/// Get a copy of the currently-loaded Mach headers list.
///
/// - Returns: A list of Mach headers loaded into the current process. The order
///   of the resulting list is unspecified.
///
/// On non-Apple platforms, the `swift_enumerateAllMetadataSections()` function
/// exported by the runtime serves the same purpose as this function.
static SWTMachHeaderList getMachHeaders(void) {
  /// This list is necessarily mutated while a global libobjc- or dyld-owned
  /// lock is held. Hence, code using this list must avoid potentially
  /// re-entering either library (otherwise it could potentially deadlock.)
  ///
  /// To see how the Swift runtime accomplishes the above goal, see
  /// `ConcurrentReadableArray` in that project's Concurrent.h header. Since the
  /// testing library is not tasked with the same performance constraints as
  /// Swift's runtime library, we just use a `std::vector` guarded by an unfair
  /// lock.
  static constinit SWTMachHeaderList *machHeaders = nullptr;
  static constinit os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

  static constinit dispatch_once_t once = 0;
  dispatch_once_f(&once, nullptr, [] (void *) {
    machHeaders = reinterpret_cast<SWTMachHeaderList *>(std::malloc(sizeof(SWTMachHeaderList)));
    ::new (machHeaders) SWTMachHeaderList();
    machHeaders->reserve(_dyld_image_count());

    objc_addLoadImageFunc([] (const mach_header *mh) {
      os_unfair_lock_lock(&lock); {
        machHeaders->push_back(reinterpret_cast<SWTMachHeaderList::value_type>(mh));
      } os_unfair_lock_unlock(&lock);
    });
  });

  // After the first call sets up the loader hook, all calls take the lock and
  // make a copy of whatever has been loaded so far.
  SWTMachHeaderList result;
  os_unfair_lock_lock(&lock); {
    result = *machHeaders;
  } os_unfair_lock_unlock(&lock);
  return result;
}

template <typename SectionEnumerator>
static void enumerateTypeMetadataSections(const SectionEnumerator& body) {
  SWTMachHeaderList machHeaders = getMachHeaders();
  for (auto mh : machHeaders) {
    unsigned long size = 0;
    const void *section = getsectiondata(mh, SEG_TEXT, "__swift5_types", &size);
    if (section && size > 0) {
      body(section, size);
    }
  }
}

#elif defined(__linux__) || defined(_WIN32)
#pragma mark - Linux/Windows implementation

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
    const auto& body = *reinterpret_cast<const SectionEnumerator *>(context);
    MetadataSectionRange section = sections->swift5_type_metadata;
    if (section.start && section.length > 0) {
      body(reinterpret_cast<const void *>(section.start), section.length);
    }
    return true;
  }, const_cast<SectionEnumerator *>(&body));
}
#else
#warning Platform-specific implementation missing: Runtime test discovery unavailable
template <typename SectionEnumerator>
static void enumerateTypeMetadataSections(const SectionEnumerator& body) {}
#endif

#pragma mark -

void swt_enumerateTypes(void *context, SWTTypeEnumerator body, SWTTypeNameFilter nameFilter) {
  enumerateTypeMetadataSections([=] (const void *section, size_t size) {
    auto records = reinterpret_cast<const SWTTypeMetadataRecord *>(section);
    size_t recordCount = size / sizeof(SWTTypeMetadataRecord);

    for (size_t i = 0; i < recordCount; i++) {
      const auto& record = records[i];

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

      // If the caller supplied a name filtering function, check that the type's
      // name passes. This will be more expensive than the checks above, but
      // should be cheaper than realizing the metadata.
      if (nameFilter) {
        const char *typeName = contextDescriptor->getName();
        bool nameOK = typeName && (* nameFilter)(typeName, context);
        if (!nameOK) {
          continue;
        }
      }

      if (void *typeMetadata = contextDescriptor->getMetadata()) {
        body(typeMetadata, context);
      }
    }
  });
}
