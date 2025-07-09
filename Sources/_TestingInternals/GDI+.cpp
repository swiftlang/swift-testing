//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#include "GDI+.h"

#include <gdiplus.h>
#include <shlwapi.h>

using Gdiplus;

ULONG_PTR swt_gdiplus_startup(int *outError) {
  ULONG_PTR result = nullptr;

  GdiplusStartupInput input;
  auto status = GdiplusStartup(&result, &input, nullptr);

  if (status != Ok) {
    *outError = static_cast<int>(status);
  }
  return result;
}

void swt_gdiplus_shutdown(ULONG_PTR *token) {
  (void)GdiplusShutdown(token);
}

void *swt_gdiplus_createImageFromHBITMAP(HBITMAP bitmap, HPALETTE palette) {
  return Bitmap::FromHBITMAP(bitmap, palette);
}

void swt_gdiplus_destroyImage(void *image) {
  auto bitmap = reinterpret_cast<Bitmap *>(image);
  delete bitmap;
}

void *swt_gdiplus_copyBytes(void *image, const CLSID *clsid, size_t *outByteCount, int *outError) {
  auto bitmap = reinterpret_cast<Bitmap *>(image);

  // Create an IStream in memory and save the image to it.
  auto stream = SHCreateMemStream(nullptr, 0);
  auto status = bitmap->Save(stream, clsid);

  // Read back from the stream into 
  (void)stream->Seek(0, STREAM_SEEK_SET, nullptr);

  stream->Release();

  if (status != Ok) {
    *outError = static_cast<int>(status);
  }
  return nullptr;
}
