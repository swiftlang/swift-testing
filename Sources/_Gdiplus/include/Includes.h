//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_GDIPLUS_INCLUDES_H)
#define SWT_GDIPLUS_INCLUDES_H

#include <Windows.h>
#include <Gdiplus.h>

static inline Gdiplus::Status swt_winsdk_GdiplusStartup(
  ULONG_PTR *token,
  const Gdiplus::GdiplusStartupInput *input,
  Gdiplus::GdiplusStartupOutput *output
) {
  return Gdiplus::GdiplusStartup(token, input, output);
}

static inline void swt_winsdk_GdiplusShutdown(ULONG_PTR token) {
  Gdiplus::GdiplusShutdown(token);
}

static inline Gdiplus::Image *swt_winsdk_GdiplusBitmapCreate(HBITMAP bitmap, HPALETTE palette) {
  return Gdiplus::Bitmap::FromHBITMAP(bitmap, palette);
}

static inline void swt_winsdk_GdiplusImageDelete(Gdiplus::Image *image) {
  delete image;
}

static inline Gdiplus::Status swt_winsdk_GdiplusImageSave(
  Gdiplus::Image *image,
  IStream *stream,
  const CLSID *format,
  const Gdiplus::EncoderParameters *encoderParams
) {
  return image->Save(stream, format, encoderParams);
}

static inline void swt_winsdk_IStreamRelease(IStream *stream) {
  stream->Release();
}
#endif
