//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SML_INTERFACE_H)
#define SML_INTERFACE_H

#include "Defines.h"

#include <stdbool.h>

SML_ASSUME_NONNULL_BEGIN

typedef struct SMLImage {
  const void *base;
#if defined(_WIN32)
  const wchar_t *_Nullable name;
#else
  const char *_Nullable name;
#endif
#if defined(_WIN32)
  wchar_t nameBuffer[2048];
#elif defined(DEBUG)
  char did_you_forget_windows_has_an_array_here[1];
#endif
} SMLImage;

SML_EXTERN void sml_getMainImage(SMLImage *outImage);

typedef void (* SMLImageEnumerator)(void *_Null_unspecified context, const SMLImage *image, bool *stop);

SML_EXTERN void sml_enumerateImages(void *_Null_unspecified context, SMLImageEnumerator body);

SML_EXTERN bool sml_getImageContainingAddress(const void *address, SMLImage *outImage);

SML_ASSUME_NONNULL_END

#endif
