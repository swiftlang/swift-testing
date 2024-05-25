//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SML_SECTION_H)
#define SML_SECTION_H

#include "Defines.h"

#include <stddef.h>
#include <stdint.h>

SML_ASSUME_NONNULL_BEGIN

typedef struct SMLSection {
  const void *start;
  size_t size;
} SMLSection;

SML_EXTERN bool sml_findSection(const SMLImage *image, const char *sectionName, SMLSection *outSection);

SML_ASSUME_NONNULL_END

#endif
