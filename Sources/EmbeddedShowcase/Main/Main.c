//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_EMBEDDED
#include <stdio.h>
#include <stdlib.h>
#else
#include "../../_TestingInternals/include/EmbeddedPlatform.h"
#endif

int main(
  int argc, char *argv[]
#if !defined(__wasi__)
  , char *envp[]
#endif
) {
#if !SWT_EMBEDDED
  fputs("This target is intended for Embedded Swift only.\n", stderr);
  return EXIT_FAILURE;
#elif !defined(__wasi__)
  swift_testing_embeddedMain(argc, argv, envp);
#else
  swift_testing_embeddedMain(argc, argv, 0);
#endif
}
