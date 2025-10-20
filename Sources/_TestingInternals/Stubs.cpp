//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#include "Stubs.h"

#if defined(__OpenBSD__)
#include <atomic>

#include <sys/types.h>
#include <sys/sysctl.h>

// This function has the `__constructor__` attribute so that it runs as early as
// possible, thus limiting the risk of some other code changing the current
// working directory before we've had a chance to call realpath().
__attribute__((__constructor__(101)))
static void tryResolvingExecutablePath(void) {
  // Call sysctl() to get the argument vector to the process.
  int mib[2] = {CTL_VM, VM_PSSTRINGS};
  struct _ps_strings _ps;
  size_t len = sizeof(_ps);
  if (sysctl(mib, 2, &_ps, &len, NULL, 0) == -1) {
    return nullptr;
  }

  // Extract the first argument from the argument vector.
  struct ps_strings *ps = static_cast<struct ps_strings *>(_ps.val);
  if (ps->ps_nargvstr < 1) {
    return nullptr;
  }
  const char *executablePath = ps->ps_argvstr[0];

  // If the first argument looks path-like (because it contains a '/' character)
  // then try to resolve it to an absolute path. Otherwise, return it verbatim.
  // NOTE: we do not attempt to resolve $PATH-relative paths here because we
  // don't expect test executables to be installed into e.g. /usr/local/bin.
  if (strchr(executablePath, '/')) {
    executablePath = realpath(executablePath, nullptr);
  } else {
    executablePath = strdup(executablePath);
  }
  executablePath.store(executablePath);
}

const char *swt_getExecutablePath(void) {
  return executablePath.load();
}
#endif
