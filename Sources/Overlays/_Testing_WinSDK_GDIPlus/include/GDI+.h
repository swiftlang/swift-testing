//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_GDIPLUS_H)
#define SWT_GDIPLUS_H

#include <Initguid.h>

/// This header includes thunk functions for various GDI+ functions that the
/// Swift importer is currently unable to import. As such, I haven't documented
/// each function individually; refer to the GDI+ documentation for more
/// information about the thunked functions.

#if defined(_WIN32)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmicrosoft-include"
#include "../../_TestingInternals/include/Defines.h"
#include "../../_TestingInternals/include/Includes.h"
#pragma clangdiagnostic pop

SWT_ASSUME_NONNULL_BEGIN

/// A type representing a GDI+ status code (equivalent to `Gdiplus::Status`.)
typedef int SWTGDIPlusStatusCode __attribute__((swift_newtype(struct)));

/// The "OK" GDI+ status code.
SWT_EXTERN const SWTGDIPlusStatusCode SWTGDIPlusStatusCodeOK SWT_SWIFT_NAME(SWTGDIPlusStatusCode.ok);

/// Start GDI+.
///
/// - Parameters:
///   - token: On return, a unique token that can be passed to
///     ``swt_GdiplusShutdown(_:)`` when GDI+ is no longer needed.
///
/// - Returns: Whether or not the operation was successful.
///
/// A call to this function must be paired with a later call to
/// ``swt_GdiplusShutdown(_:)``.
SWT_EXTERN SWTGDIPlusStatusCode swt_GdiplusStartup(ULONG_PTR *token);

/// Shut down GDI+.
///
/// - Parameters:
///   - token: A token previously returned from ``swt_GdiplusStartup(_:_:)``.
SWT_EXTERN void swt_GdiplusShutdown(ULONG_PTR token);

// MARK: - Gdiplus::Image

/// A type representing a GDI+ image of type `Gdiplus::Image` that can be used
/// in Swift.
typedef struct SWTGDIPlusImage {
  void *opaque;
} SWTGDIPlusImage;

/// Create a GDI+ image from an `HBITMAP` instance.
///
/// - Parameters:
///   - bitmap: The bitmap.
///   - palette: Optionally, a palette associated with `bitmap`.
///
/// - Returns: A new GDI+ image. The caller is responsible for ensuring that
///   `bitmap` and `palette` remain valid until this image is deleted.
SWT_EXTERN SWTGDIPlusImage *swt_GdiplusImageCreateFromHBITMAP(HBITMAP bitmap, HPALETTE _Nullable palette);

/// Create a GDI+ image from an `HICON` instance.
///
/// - Parameters:
///   - icon: The icon.
///
/// - Returns: A new GDI+ image. The caller is responsible for ensuring that
///   `icon` remains valid until this image is deleted.
SWT_EXTERN SWTGDIPlusImage *swt_GdiplusImageCreateFromHICON(HICON icon);

/// Create a GDI+ image from a COM object.
///
/// - Parameters:
///   - object: The COM object.
///
/// - Returns: A new GDI+ image, or `nullptr` if `object` was not of a supported
///   COM type. The implementation holds a reference to `object` until the image
///   is deleted or `object` is no longer needed.
SWT_EXTERN SWTGDIPlusImage *_Nullable swt_GdiplusImageCreateFromIUnknown(IUnknown *object);

/// Delete a GDI+ image previously created with a function in this library.
///
/// - Parameters:
///   - image: The image to delete.
SWT_EXTERN void swt_GdiplusImageDelete(SWTGDIPlusImage *image);

/// Save a GDI+ image to a stream.
///
/// - Parameters:
///   - image: The image to save.
///   - stream: The stream to save `image` to.
///   - format: A `CLSID` instance representing the image format to use.
///   - encodingQuality: If not `nullptr`, the encoding quality to use.
///
/// - Returns: Whether or not the operation was successful.
SWT_EXTERN SWTGDIPlusStatusCode swt_GdiplusImageSave(
  SWTGDIPlusImage *image,
  IStream *stream,
  CLSID format,
  const float *_Nullable encodingQuality
);

// MARK: - Gdiplus::ImageCodecInfo

/// A type representing information about a GDI+ image codec of type
/// `Gdiplus::ImageCodecInfo` that can be used in Swift.
typedef struct SWTGDIPlusImageCodecInfo {
  void *opaque;
} SWTGDIPlusImageCodecInfo;

/// Copy all image codecs known to GDI+ that can be used for encoding.
///
/// - Parameters:
///   - outInfo: On success, set to an array of pointers to information about
///     the various codecs supported by GDI+. 
///   - outCount: On success, set to the number of codecs returned.
///
/// - Returns: Whether or not the operation was successful.
SWT_EXTERN SWTGDIPlusStatusCode swt_GdiplusCopyAllImageCodecInfo(
  SWTGDIPlusImageCodecInfo const *_Nonnull *_Nullable *_Nonnull outInfo,
  size_t *outCount
);

/// Get the `CLSID` value associated with a GDI+ image codec.
///
/// - Parameters:
///   - info: Information about the codec of interest.
///
/// - Returns: The `CLSID` value associated with `info`.
SWT_EXTERN CLSID swt_GdiplusImageCodecInfoGetCLSID(const SWTGDIPlusImageCodecInfo *info);

/// Get a string containing the filename extensions associated with a GDI+
/// image codec.
///
/// - Parameters:
///   - info: Information about the codec of interest.
///
/// - Returns: A pointer to a wide-character C string containing zero or more
///   path extensions associated with `info`. The format of this string is
///   described in Microsoft's GDI+ documentation. The caller must not
///   deallocate this string.
SWT_EXTERN const wchar_t *swt_GdiplusImageCodecInfoGetFilenameExtension(const SWTGDIPlusImageCodecInfo *info);

SWT_ASSUME_NONNULL_END

#endif
#endif
