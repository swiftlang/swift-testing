//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_AVAILABILITY
#if defined(__swift__)

#if !defined(SWT_AVAILABILITY_H)
#define SWT_AVAILABILITY_H

#include "Defines.h"

#include <availability_domain.h>

// _SWIFT_TESTING_EXPERIMENTAL_DEVELOPMENT_AVAILABILITY is a tri-state setting:
// - enabled: TestingExperimentalDevelopmentOnly domain is active. Test content is included.
// - disabled: TestingExperimentalDevelopmentOnly domain is inactive. No test content is included.
// - unset: TestingExperimentalDevelopmentOnly domain is always enabled. No checking applied.
// Any other value is an error.

#ifndef _SWIFT_TESTING_EXPERIMENTAL_DEVELOPMENT_AVAILABILITY
  CLANG_ALWAYS_ENABLED_AVAILABILITY_DOMAIN(TestingExperimentalDevelopmentOnly);
#else
  #define _SWIFT_TESTING_EXPERIMENTAL_DEVELOPMENT_AVAILABILITY_enabled 1
  #define _SWIFT_TESTING_EXPERIMENTAL_DEVELOPMENT_AVAILABILITY_disabled 2

  #define _SWT_MODE SWT_CONCAT(_SWIFT_TESTING_EXPERIMENTAL_DEVELOPMENT_AVAILABILITY_, _SWIFT_TESTING_EXPERIMENTAL_DEVELOPMENT_AVAILABILITY)

  #if _SWT_MODE == 1
    CLANG_ENABLED_AVAILABILITY_DOMAIN(TestingExperimentalDevelopmentOnly);
  #elif _SWT_MODE == 2
    CLANG_DISABLED_AVAILABILITY_DOMAIN(TestingExperimentalDevelopmentOnly);
  #else
    #error "_SWIFT_TESTING_EXPERIMENTAL_DEVELOPMENT_AVAILABILITY must be 'enabled' or 'disabled'"
  #endif

  #undef _SWT_MODE
  #undef _SWIFT_TESTING_EXPERIMENTAL_DEVELOPMENT_AVAILABILITY_enabled
  #undef _SWIFT_TESTING_EXPERIMENTAL_DEVELOPMENT_AVAILABILITY_disabled
#endif

#endif // SWT_AVAILABILITY_H

#endif // defined(__swift__)
#endif // !SWT_NO_AVAILABILITY
