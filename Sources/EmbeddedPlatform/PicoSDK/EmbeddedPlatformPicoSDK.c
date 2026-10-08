//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if defined(SWT_EMBEDDED) && __has_include("pico/stdlib.h")
// C Standard Library headers
#include <malloc.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// Pico SDK headers
#include "pico/time.h"
#include "pico/status_led.h"
#include "pico/stdlib.h"
#include "pico/version.h"

// Swift Testing headers
#include "../../_TestingInternals/include/EmbeddedPlatform+Testing.h"

// MARK: - POSIX stubs

// These functions are used by the core Platform Abstraction Layer and are
// expected to be present on a POSIX-compliant system, but are not implemented
// in newlib.
//
// The minal implementations below satisfy the Platform Abstraction Layer's
// requirements, but may not implement all the functionality specified by POSIX.

int __error = 0;

int clock_gettime(clockid_t clockid, struct timespec *tp) {
  uint64_t us = time_us_64();
  tp->tv_sec = us / 1000000;
  tp->tv_nsec = us % 1000000000;
  return 0;
}

int memset_s(void *dest, size_t destsz, int ch, size_t count) {
  memset(dest, ch, count);
  return 0;
}

int _nanosleep(const struct timespec *duration, struct timespec *rem) {
  sleep_us(duration->tv_sec * 1000000);
  sleep_us(duration->tv_nsec / 1000);
  memset(rem, 0, sizeof(*rem));
  return 0;
}

int posix_memalign(void **memptr, size_t alignment, size_t size) {
  void *result = memalign(alignment, size);
  if (result) {
    *memptr = result;
    return 0;
  }
  return -1;
}

// MARK: - swift_Concurrency stubs

// These functions should be implemented in Swift's _Concurrency module but are
// currently missing. They will be removed in a future update.

#if __has_attribute(__swiftcall__)
__attribute__((__swiftcall__))
#endif
void _task_serialExecutor_checkIsolated(const void *executor, const void *selfType, const void *wtable) {}

#if __has_attribute(__swiftcall__)
__attribute__((__swiftcall__))
#endif
int8_t _task_serialExecutor_isIsolatingCurrentContext(const void *executor, const void *selfType, const void *wtable) {
  return -1; // unknown
}

// MARK: -

bool _swift_testing_getArgcArgv(swift_testing_argc_argv_t *outArgcArgv) {
  static char *argv[] = { "swift-test", "--verbose" };
  outArgcArgv->argc = 2;
  outArgcArgv->argv = argv;
  return true;
}

bool _swift_testing_getEnvironment(char *_Nullable *_Nullable *_Nonnull outEnvironment) {
  return false;
}

bool _swift_testing_getEmbeddedTargetInfo(const char **outEmbeddedTargetInfo) {
  *outEmbeddedTargetInfo = PICO_PLATFORM_STRING " (Pico SDK " PICO_SDK_VERSION_STRING ")";
  return true;
}

bool _swift_testing_getConsoleCapabilities(swift_testing_console_capabilities_t *outConsoleCapabilities) {
  return false;
}

static atomic_flag _statusLEDInitialized = ATOMIC_FLAG_INIT;
static atomic_flag _stdioInitialized = ATOMIC_FLAG_INIT;

void _swift_testing_writeToConsole(const uint8_t *chars, size_t count) {
  if (!atomic_flag_test_and_set(&_statusLEDInitialized)) {
    status_led_init();
  }
  if (!atomic_flag_test_and_set(&_stdioInitialized)) {
    stdio_init_all();
  }

  status_led_set_state(true);
  stdio_put_string((const char *)chars, count, false, PICO_STDIO_DEFAULT_CRLF);
  status_led_set_state(false);
}

bool _swift_testing_initJSONWriter(const char *path, swift_testing_json_writer_t *outWriter) {
  return false;
}

void _swift_testing_writeJSON(const swift_testing_json_writer_t *writer, const uint8_t *json, size_t count, const uint8_t terminator[1]) {}

void _swift_testing_deinitJSONWriter(swift_testing_json_writer_t *writer) {}

bool _swift_testing_getDurationSinceSystemEpoch(swift_testing_duration_t *outDuration) {
  uint64_t us = time_us_64();
  outDuration->seconds = us / 1000000;
  outDuration->nanoseconds = (us % 1000000) * 1000;
  return true;
}

#endif
