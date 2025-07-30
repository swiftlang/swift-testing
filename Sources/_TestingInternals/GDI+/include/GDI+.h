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

#if defined(_WIN32) && defined(__cplusplus)
#include "../include/Defines.h"
#include "../include/Includes.h"

#include <Gdiplus.h>

SWT_ASSUME_NONNULL_BEGIN

static inline Gdiplus::Status swt_GdiplusStartup(
  ULONG_PTR *token,
  const Gdiplus::GdiplusStartupInput *input,
  Gdiplus::GdiplusStartupOutput *_Nullable output
) {
  return Gdiplus::GdiplusStartup(token, input, output);
}

static inline void swt_GdiplusShutdown(ULONG_PTR token) {
  Gdiplus::GdiplusShutdown(token);
}

static inline Gdiplus::Bitmap *_Nullable swt_GdiplusBitmapFromHBITMAP(HBITMAP bitmap, HPALETTE _Nullable palette) {
  return Gdiplus::Bitmap::FromHBITMAP(bitmap, palette);
}

static inline Gdiplus::Bitmap *_Nullable swt_GdiplusBitmapFromHICON(HICON icon) {
  return Gdiplus::Bitmap::FromHICON(icon);
}

static inline void swt_GdiplusBitmapDelete(Gdiplus::Bitmap *bitmap) {
  delete bitmap;
}

static inline Gdiplus::Status swt_GdiplusBitmapSave(
  Gdiplus::Bitmap *bitmap,
  IStream *stream,
  const CLSID *format,
  const Gdiplus::EncoderParameters *_Nullable encoderParams
) {
  return bitmap->Save(stream, format, encoderParams);
}

SWT_ASSUME_NONNULL_END

#endif
#endif
