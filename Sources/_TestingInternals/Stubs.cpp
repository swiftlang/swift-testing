//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// This source file includes implementations of functions that _should_ simply
/// be `static` stubs in Stubs.h, but which for technical reasons cannot be
/// imported into Swift when defined in a header.
///
/// Do not, as a rule, add function implementations in this file. Prefer to add
/// them to Stubs.h so that they can be inlined at compile- or link-time. Only
/// include functions here if Swift cannot successfully import and call them
/// otherwise.

#undef _DEFAULT_SOURCE
#define _DEFAULT_SOURCE 1
#undef _GNU_SOURCE
#define _GNU_SOURCE 1

#include "Stubs.h"

#if defined(__linux__)
int swt_pthread_setname_np(pthread_t thread, const char *name) {
  return pthread_setname_np(thread, name);
}
#endif

#if defined(__GLIBC__)
int swt_posix_spawn_file_actions_addclosefrom_np(posix_spawn_file_actions_t *fileActions, int from) {
  int result = 0;

#if defined(__GLIBC_PREREQ)
#if __GLIBC_PREREQ(2, 34)
  result = posix_spawn_file_actions_addclosefrom_np(fileActions, from);
#endif
#endif

  return result;
}
#endif

#if defined(__ELF__)
int swt_dl_iterate_phdr(void *context, int (*callback)(const void *dlpi_addr, const ElfW(Phdr) *dlpi_phdr, size_t dlpi_phnum, void *context)) {
  struct Context {
    void *context;
    decltype(callback) callback;
  };
  Context ctx = { context, callback };

  return dl_iterate_phdr([] (struct dl_phdr_info *info, size_t size, void *ctx) -> int {
    auto [context, callback] = *reinterpret_cast<const Context *>(ctx);
    return callback(
      reinterpret_cast<const void *>(info->dlpi_addr),
      info->dlpi_phdr,
      info->dlpi_phnum,
      context
    );
  }, &ctx);
}
#endif
