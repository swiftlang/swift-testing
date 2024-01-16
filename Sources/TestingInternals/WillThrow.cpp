//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#include "WillThrow.h"

#include <cstdint> // must come before <atomic>
#include <atomic>

/// The Swift runtime error-handling hook.
SWT_IMPORT_FROM_STDLIB std::atomic<SWTWillThrowHandler> _swift_willThrow;

SWTWillThrowHandler swt_setWillThrowHandler(SWTWillThrowHandler handler) {
  return _swift_willThrow.exchange(handler, std::memory_order_acq_rel);
}
