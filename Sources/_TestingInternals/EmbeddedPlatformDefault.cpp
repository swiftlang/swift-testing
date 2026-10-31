//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#include "EmbeddedPlatform+Testing.h"

#if defined(SWT_EMBEDDED)
SWIFT_TESTING_WEAK bool _swift_testing_getArgcArgv(swift_testing_argc_argv_t *outArgcArgv) {
  return false;
}

SWIFT_TESTING_WEAK bool _swift_testing_getEnvironment(char *_Nullable *_Nullable *_Nonnull outEnvironment) {
  return false;
}

SWIFT_TESTING_WEAK bool _swift_testing_getEmbeddedTargetInfo(const char **outEmbeddedTargetInfo) {
  return false;
}

SWIFT_TESTING_WEAK bool _swift_testing_getConsoleCapabilities(swift_testing_console_capabilities_t *outConsoleCapabilities) {
  return false;
}

SWIFT_TESTING_WEAK void _swift_testing_writeJSON(const char *path, const uint8_t *json, size_t count, const uint8_t terminator[1]) {}

SWIFT_TESTING_WEAK bool _swift_testing_getDurationSinceSystemEpoch(swift_testing_duration_t *outDuration) {
  return false;
}
#endif
