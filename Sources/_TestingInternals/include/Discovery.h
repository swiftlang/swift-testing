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
#if defined(__ELF__)
typedef ElfW(Nhdr) SWTTestContentHeader;
#else
typedef struct SWTTestContentHeader {
  int32_t n_namesz;
  int32_t n_descsz;
  int32_t n_type;
} SWTTestContentHeader;
#endif

/// The type of callback called by `swt_enumerateTestContent()`.
///
/// - Parameters:
///   - imageAddress: The base address of the image containing the test content,
///     if available.
///   - header: A pointer to the start of a structure containing information
///     about the enumerated test content.
///   - stop: A pointer to a boolean variable indicating whether test content
///     enumeration should stop after the function returns. Set `*stop` to
///     `true` to stop test content enumeration.
///   - context: An arbitrary pointer passed by the caller to
///     `swt_enumerateTestContent()`.
typedef void (* SWTTestContentEnumerator)(const void *_Null_unspecified imageAddress, const SWTTestContentHeader *header, bool *stop, void *_Null_unspecified context);

/// Enumerate all test content known to Swift and found in the current process.
///
/// - Parameters:
///   - context: An arbitrary pointer to pass to `body`.
///   - body: A function to invoke, once per matching type.
SWT_EXTERN void swt_enumerateTestContent(
  void *_Null_unspecified context,
  SWTTestContentEnumerator body
) SWT_SWIFT_NAME(swt_enumerateTestContent(_:_:));

SWT_ASSUME_NONNULL_END

#endif
