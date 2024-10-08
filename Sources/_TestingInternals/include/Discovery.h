//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_DISCOVERY_H)
#define SWT_DISCOVERY_H

#include "Defines.h"
#include "Includes.h"

SWT_ASSUME_NONNULL_BEGIN

#pragma mark - Test content records

/// A redeclaration of `ElfW(Nhdr)` for platforms that do not use ELF binaries.
///
/// The layout of this type is equivalent to that of an ELF Note header
/// (`ElfW(Nhdr)`). On platforms that use the ELF binary format, instances of
/// this type can be found in program headers of type `PT_NOTE`. On other
/// platforms, instances of this type can be found in dedicated
/// platform-specific locations (for Mach-O and COFF/PE, the
/// `"__DATA_CONST,__swift5_tests"` and `".sw5test"` sections, respectively.)
///
/// For more information about the ELF binary format and ELF Notes specifically,
/// review the documentation for the ELF binary format. Multiple vendors
/// including the [Linux Kernel project](https://man7.org/linux/man-pages/man5/elf.5.html)
/// and [FreeBSD](https://man.freebsd.org/cgi/man.cgi?elf(5)) provide
/// substantively identical documentation.
///
/// - Note: This type is declared in C++ so that its layout precisely matches
///   between languages. Any code that uses this type should be written in Swift
///   if possible.
#if defined(__ELF__)
typedef ElfW(Nhdr) SWTTestContentHeader;
#else
typedef struct SWTTestContentHeader {
  int32_t n_namesz;
  int32_t n_descsz;
  int32_t n_type;
} SWTTestContentHeader;
#endif

/// The type of a test content accessor.
///
/// - Parameters:
///   - outValue: On successful return, initialized to the value of the
///     represented test content record.
///   - hint: A hint value whose type and meaning depend on the type of test
///     record being accessed.
///
/// - Returns: Whether or not the test record was initialized at `outValue`. If
///   this function returns `true`, the caller is responsible for deinitializing
///   the memory at `outValue` when done.
typedef bool (* SWTTestContentAccessor)(void *outValue, const void *_Null_unspecified hint);

/// Resign an accessor function from a test content record.
///
/// - Parameters:
///   - accessor: The accessor function to resign.
///
/// - Returns: A resigned copy of `accessor` on platforms that use pointer
///   authentication, and an exact copy of `accessor` elsewhere.
///
/// This function is provided because Apple's pointer authentication intrinsics
/// are not available in Swift.
SWT_SWIFT_NAME(swt_resign(_:))
static SWTTestContentAccessor swt_resignTestContentAccessor(SWTTestContentAccessor accessor) {
#if defined(__APPLE__) && __has_include(<ptrauth.h>)
  accessor = ptrauth_strip(accessor, ptrauth_key_function_pointer);
  accessor = ptrauth_sign_unauthenticated(accessor, ptrauth_key_function_pointer, 0);
#endif
  return accessor;
}

/// The content of a test content record.
///
/// - Note: This type is declared in C++ so that its layout precisely matches
///   between languages. Any code that uses this type should be written in Swift
///   if possible.
typedef struct SWTTestContent {
  /// A function which, when called, produces the test content as a retained
  /// Swift object.
  SWTTestContentAccessor _Null_unspecified accessor;

  /// Flags for this record. The meaning of this value is dependent on the kind
  /// of test content this instance represents.
  uint32_t flags;

  /// This field is reserved for future use.
  uint32_t reserved;
} SWTTestContent;

#if defined(SWT_NO_DYNAMIC_LINKING)
#pragma mark - Statically-linked section bounds

/// The bounds of the test content section statically linked into the image
/// containing Swift Testing.
SWT_EXTERN const void *_Nonnull const SWTTestContentSectionBounds[2];
#endif

#if !defined(SWT_NO_LEGACY_TEST_DISCOVERY)
#pragma mark - Legacy test discovery

/// The type of callback called by `swt_enumerateTypes()`.
///
/// - Parameters:
///   - imageAddress: A pointer to the start of the image. This value is _not_
///     equal to the value returned from `dlopen()`. On platforms that do not
///     support dynamic loading (and so do not have loadable images), this
///     argument is unspecified.
///   - typeMetadata: A type metadata pointer that can be bitcast to `Any.Type`.
///   - stop: A pointer to a boolean variable indicating whether type
///     enumeration should stop after the function returns. Set `*stop` to
///     `true` to stop type enumeration.
///   - context: An arbitrary pointer passed by the caller to
///     `swt_enumerateTypes()`.
typedef void (* SWTTypeEnumerator)(const void *_Null_unspecified imageAddress, void *typeMetadata, bool *stop, void *_Null_unspecified context);

/// Enumerate all types known to Swift found in the current process.
///
/// - Parameters:
///   - nameSubstring: A string which the names of matching classes all contain.
///   - context: An arbitrary pointer to pass to `body`.
///   - body: A function to invoke, once per matching type.
SWT_EXTERN void swt_enumerateTypesWithNamesContaining(
  const char *nameSubstring,
  void *_Null_unspecified context,
  SWTTypeEnumerator body
) SWT_SWIFT_NAME(swt_enumerateTypes(withNamesContaining:_:_:));
#endif

SWT_ASSUME_NONNULL_END

#endif
