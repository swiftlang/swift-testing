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

#if defined(SWT_NO_DYNAMIC_LINKING)
#pragma mark - Statically-linked section bounds

#if defined(__APPLE__)
extern "C" const char testContentSectionBegin __asm("section$start$__DATA_CONST$__swift5_tests");
extern "C" const char testContentSectionEnd __asm("section$end$__DATA_CONST$__swift5_tests");
extern "C" const char typeMetadataSectionBegin __asm__("section$start$__TEXT$__swift5_types");
extern "C" const char typeMetadataSectionEnd __asm__("section$end$__TEXT$__swift5_types");
#elif defined(__wasi__)
extern "C" const char testContentSectionBegin __asm__("__start_swift5_tests");
extern "C" const char testContentSectionEnd __asm__("__stop_swift5_tests");
extern "C" const char typeMetadataSectionBegin __asm__("__start_swift5_type_metadata");
extern "C" const char typeMetadataSectionEnd __asm__("__stop_swift5_type_metadata");
#else
#warning Platform-specific implementation missing: Runtime test discovery unavailable (static)
static const char testContentSectionBegin = 0;
static const char& testContentSectionEnd = testContentSectionBegin;
static const char typeMetadataSectionBegin = 0;
static const char& typeMetadataSectionEnd = testContentSectionBegin;
#endif

/// The bounds of the test content section statically linked into the image
/// containing Swift Testing.
const void *_Nonnull const SWTTestContentSectionBounds[2] = {
  &testContentSectionBegin,
  &testContentSectionEnd
};

/// The bounds of the type metadata section statically linked into the image
/// containing Swift Testing.
const void *_Nonnull const SWTTypeMetadataSectionBounds[2] = {
  &typeMetadataSectionBegin,
  &typeMetadataSectionEnd
};
#endif

#pragma mark - Legacy test discovery

#include <algorithm>
#include <array>
#include <atomic>
#include <cstring>
#include <iterator>
#include <memory>
#include <tuple>
#include <type_traits>
#include <vector>
#include <optional>

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

#pragma mark -

void **swt_copyTypesWithNamesContaining(const void *sectionBegin, size_t sectionSize, const char *nameSubstring, size_t *outCount) {
  SWTSectionBounds<SWTTypeMetadataRecord> sb = { nullptr, sectionBegin, sectionSize };
  std::vector<void *, SWTHeapAllocator<void *>> result;

  for (const auto& record : sb) {
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
      result.push_back(typeMetadata);
    }
  }

  auto resultCopy = reinterpret_cast<void **>(std::calloc(sizeof(void *), result.size()));
  if (resultCopy) {
    std::uninitialized_move(result.begin(), result.end(), resultCopy);
    *outCount = result.size();
  }
  return resultCopy;
}
