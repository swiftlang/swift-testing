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

#pragma mark Test content sections

/// A structure describing the bounds of a Swift metadata section.
///
/// - Note: This type is declared in C++ so that its layout precisely matches
///   between languages. Any code that uses this type should be written in Swift
///   if possible.
typedef struct SWTSectionBounds {
  /// The base address of the image containing the section, if known.
  const void *_Null_unspecified imageAddress;

  /// The base address of the section.
  const void *start;

  /// The size of the section in bytes.
  size_t size;
} SWTSectionBounds;

/// Get all test content sections known to Swift and found in the current
/// process.
///
/// - Parameters:
///   - outCount: On return, the number of section bounds in the result.
///
/// - Returns: A pointer to zero or more structures describing the bounds of
///   test content sections known to Swift and found in the current process.
SWT_EXTERN SWTSectionBounds *swt_copyTestContentSectionBounds(size_t *outCount);

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
/// 	- outValue: On successful return, initialized to the value of the
///   	represented test content record.
///   - hint: A hint value whose type and meaning depend on the type of test
///   	record being accessed.
///
/// - Returns: Whether or not the test record was initialized at `outValue`. If
///   this function returns `true`, the caller is responsible for deinitializing
///   the memory at `outValue` when done.
typedef bool (* SWT_SENDABLE SWTTestContentAccessor)(void *outValue, const void *_Null_unspecified hint);

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
SWT_EXTERN SWTTestContentAccessor swt_resignTestContentAccessor(SWTTestContentAccessor accessor) SWT_SWIFT_NAME(swt_resign(_:));

/// The content of a test content record.
///
/// - Note: This type is declared in C++ so that its layout precisely matches
///   between languages. Any code that uses this type should be written in Swift
///   if possible.
typedef struct SWTTestContent {
  /// A function which, when called, produces the test content as a retained
  /// Swift object.
  SWTTestContentAccessor _Nullable accessor;

  /// Flags for this record. The meaning of this value is dependent on the kind
  /// of test content this instance represents.
  uint32_t flags;

  /// This field is reserved for future use.
  uint32_t reserved;
} SWTTestContent;

SWT_ASSUME_NONNULL_END

#endif
