//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_TESTING_AVAILABILITY_H)
#define SWT_TESTING_AVAILABILITY_H

#if defined(__swift__) && __has_include(<availability_domain.h>)

#include <availability_domain.h>

// SWIFT_TESTING_EXPERIMENTAL_AVAILABILITY controls the ExperimentalTesting
// domain:
// - 1: the domain is active. Test content is included.
// - 0: the domain is inactive. No test content is included.
// - Undefined: the domain is always enabled. No checking applied.
// Any other value is an error.

#if !defined(SWIFT_TESTING_EXPERIMENTAL_AVAILABILITY)
  CLANG_ALWAYS_ENABLED_AVAILABILITY_DOMAIN(ExperimentalTesting);
#elif SWIFT_TESTING_EXPERIMENTAL_AVAILABILITY == 1
  CLANG_ENABLED_AVAILABILITY_DOMAIN(ExperimentalTesting);
#elif SWIFT_TESTING_EXPERIMENTAL_AVAILABILITY == 0
  CLANG_DISABLED_AVAILABILITY_DOMAIN(ExperimentalTesting);
#else
  #error "SWIFT_TESTING_EXPERIMENTAL_AVAILABILITY must be 0 or 1"
#endif

#endif // defined(__swift__) && __has_include(<availability_domain.h>)
#endif // SWT_TESTING_AVAILABILITY_H
