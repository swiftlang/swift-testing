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

/// A type representing a binary image such as an executable or dynamic library.
typedef struct SMLImage {
  /// The base address of the loaded image.
  const void *base;

  /// The name of the image, if available.
#if defined(_WIN32)
  const wchar_t *_Nullable name;
#else
  const char *_Nullable name;
#endif
#if defined(_WIN32)
  /// Storage for ``SMLImage/name``.
  wchar_t nameBuffer[2048];
#elif defined(DEBUG)
  /// A canary value to help catch cross-platform issues using this structure.
  char did_you_forget_windows_has_an_array_here[1];
#endif
} SMLImage;

/// Get the main executable image in the current process.
///
/// - Parameters:
///   - outImage: On return, set to an instance of ``SMLImage`` representing the
///     main image of the current process.
SML_EXTERN void sml_getMainImage(SMLImage *outImage);

/// The type of callback called by `sml_enumerateImages()`.
///
/// - Parameters:
///   - context: An arbitrary pointer passed by the caller to
///     `sml_enumerateImages()`.
///   - image: A pointer to an instance of ``SMLImage`` representing an image
///     loaded into the current process.
///   - stop: A pointer to a boolean variable indicating whether image
///     enumeration should stop after the function returns. Set `*stop` to
///     `true` to stop image enumeration.
typedef void (* SMLImageEnumerator)(void *_Null_unspecified context, const SMLImage *image, bool *stop);

/// Enumerate over all images loaded into the current process.
///
/// - Parameters:
///   - context: An arbitrary pointer to pass to `body`.
///   - body: A function to call. For each image loaded into the current
///     process, an instance of ``Image`` is passed to this function.
SML_EXTERN void sml_enumerateImages(void *_Null_unspecified context, SMLImageEnumerator body);

/// Find the loaded image that contains an arbitrary address in memory.
///
/// - Parameters:
///   - address: The address whose containing image is needed.
///   - outImage: On successful return, set to an instance of ``SMLImage``
///     representing the image that contains `address`. On failure, undefined.
///
/// - Returns: Whether or not an image containing `address` was found.
SML_EXTERN bool sml_getImageContainingAddress(const void *address, SMLImage *outImage);

SML_ASSUME_NONNULL_END

#endif
