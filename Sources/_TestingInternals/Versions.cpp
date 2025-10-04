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

#include <array>
#include <algorithm>
#include <iterator>
#include <mutex>

#if defined(SWT_TESTING_LIBRARY_VERSION)
const char *swt_getTestingLibraryVersion(void) {
  // The current environment explicitly specifies a version string to return.
  // All CMake builds should take this path (see CompilerSettings.cmake.)
  return SWT_TESTING_LIBRARY_VERSION;
}
#else
// Define a global variable containing the contents of VERSION.txt using the
// .incbin assembler directive.
__asm__(
  ".global swt_testingLibraryVersion\n"
  "swt_testingLibraryVersion:\n"
  ".incbin \"VERSION.txt\"\n"
  ".byte 0\n"
);
extern "C" const char swt_testingLibraryVersion[];

const char *swt_getTestingLibraryVersion(void) {
  static char *version = nullptr;

  std::once_flag once;
  std::call_once(once, [] {
#if defined(_WIN32)
    version = _strdup(swt_testingLibraryVersion);
#else
    version = strdup(swt_testingLibraryVersion);
#endif
    auto end = version + strlen(version);
    auto i = std::find_if(version, end, [] (char c) {
      return c == '\r' || c == '\n';
    });
    std::fill(i, end, '\0');
  });

  return version;
}
#endif

void swt_getTestingLibraryCommit(const char *_Nullable *_Nonnull outHash, bool *outModified) {
#if defined(SWT_TESTING_LIBRARY_COMMIT_HASH)
  *outHash = SWT_TESTING_LIBRARY_COMMIT_HASH;
#else
  *outHash = nullptr;
#endif
#if defined(SWT_TESTING_LIBRARY_COMMIT_MODIFIED)
  *outModified = (SWT_TESTING_LIBRARY_COMMIT_MODIFIED != 0);
#else
  *outModified = false;
#endif
}

const char *swt_getTargetTriple(void) {
#if defined(SWT_TARGET_TRIPLE)
  return SWT_TARGET_TRIPLE;
#else
  // If we're here, we're presumably building as a package. Swift Package
  // Manager does not provide a way to get the target triple from within the
  // package manifest. SEE: swift-package-manager-#7929
  //
  // clang has __is_target_*() intrinsics, but we don't want to play a game of
  // Twenty Questions in order to synthesize the triple (and still potentially
  // get it wrong.) SEE: rdar://134933385
  return nullptr;
#endif
}
