//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#include "Versions.h"

const char *swt_getTestingLibraryVersion(void) {
#if defined(_SWT_TESTING_LIBRARY_VERSION)
  return _SWT_TESTING_LIBRARY_VERSION;
#else
#warning _SWT_TESTING_LIBRARY_VERSION not defined: testing library version is unavailable
  return nullptr;
#endif
}
