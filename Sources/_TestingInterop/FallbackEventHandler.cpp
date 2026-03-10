//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_NO_INTEROP)
#include "../_TestingInternals/include/FallbackEventHandler.h"

#include <atomic>

/// Storage for the fallback event handler.
static std::atomic<SWTFallbackEventHandler> fallbackEventHandler { nullptr };

bool _swift_testing_installFallbackEventHandler(SWTFallbackEventHandler handler) {
  SWTFallbackEventHandler nullptrValue = nullptr;
  return fallbackEventHandler.compare_exchange_strong(nullptrValue, handler, std::memory_order_seq_cst, std::memory_order_relaxed);
}

SWTFallbackEventHandler _swift_testing_getFallbackEventHandler(void) {
  return fallbackEventHandler.load(std::memory_order_seq_cst);
}
#endif
