//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_DEFINES_H)
#define SWT_DEFINES_H

#define SWT_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define SWT_ASSUME_NONNULL_END _Pragma("clang assume_nonnull end")

#if defined(__cplusplus)
#define SWT_EXTERN extern "C"
#else
#define SWT_EXTERN extern
#endif

#if defined(_WIN32)
#define SWT_IMPORT_FROM_STDLIB SWT_EXTERN __declspec(dllimport)
#else
#define SWT_IMPORT_FROM_STDLIB SWT_EXTERN
#endif

/// An attribute that marks some value as being `Sendable` in Swift.
#define SWT_SENDABLE __attribute__((swift_attr("@Sendable")))

/// An attribute that renames a C symbol in Swift.
#define SWT_SWIFT_NAME(name) __attribute__((swift_name(#name)))

#endif // SWT_DEFINES_H
