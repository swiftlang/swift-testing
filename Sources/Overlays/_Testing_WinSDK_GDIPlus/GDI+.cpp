//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#include "include/GDI+.h"

/// This header includes thunk functions for various GDI+ functions that the
/// Swift importer is currently unable to import. As such, I haven't documented
/// each function individually; refer to the GDI+ documentation for more
/// information about the thunked functions.

#if defined(_WIN32)
#include <Windows.h>
#include <d2d1.h>
#include <ddraw.h>
#include <Gdiplus.h>
#include <wincodec.h>

#include <algorithm>
#include <cstdlib>

using namespace Gdiplus;

const SWTGDIPlusStatusCode SWTGDIPlusStatusCodeOK = Gdiplus::Ok;

SWTGDIPlusStatusCode swt_GdiplusStartup(ULONG_PTR *token) {
  GdiplusStartupInput input;
  return GdiplusStartup(token, &input, nullptr);
}

void swt_GdiplusShutdown(ULONG_PTR token) {
  GdiplusShutdown(token);
}

// MARK: - Gdiplus::Image

SWTGDIPlusImage *swt_GdiplusImageCreateFromHBITMAP(HBITMAP bitmap, HPALETTE palette) {
  Image *result = Bitmap::FromHBITMAP(bitmap, palette);
  return reinterpret_cast<SWTGDIPlusImage *>(result);
}

SWTGDIPlusImage *swt_GdiplusImageCreateFromHICON(HICON icon) {
  Image *result = Bitmap::FromHICON(icon);
  return reinterpret_cast<SWTGDIPlusImage *>(result);
}

SWTGDIPlusImage *swt_GdiplusImageCreateFromIUnknown(IUnknown *object) {
  Image *result = nullptr;

  if (!result) {
    ID2D1Bitmap *bitmap;
    if (S_OK == object->QueryInterface<ID2D1Bitmap>(&bitmap)) {
      // TODO: convert D2D bitmap to GDI+ image
      bitmap->Release();
    }
  }

  if (!result) {
    IWICBitmap *bitmap;
    if (S_OK == object->QueryInterface<IWICBitmap>(&bitmap)) {
      // TODO: convert WIC bitmap to GDI+ image
      bitmap->Release();
    }
  }

  if (!result) {
    IDirectDrawSurface7 *surface = nullptr;
    if (S_OK == object->QueryInterface(IID_IDirectDrawSurface7, reinterpret_cast<void **>(&surface))) {
      result = Bitmap::FromDirectDrawSurface7(surface);
      surface->Release();
    }
  }

  return reinterpret_cast<SWTGDIPlusImage *>(result);
}

void swt_GdiplusImageDelete(SWTGDIPlusImage *image) {
  delete reinterpret_cast<Image *>(image);
}

SWTGDIPlusStatusCode swt_GdiplusImageSave(SWTGDIPlusImage *image, IStream *stream, CLSID format, const float *encodingQuality) {
  LONG longEncodingQuality = 0;
  EncoderParameters encoderParams = {};
  if (encodingQuality) {
    longEncodingQuality = static_cast<LONG>(*encodingQuality * 100.0);

    encoderParams.Count = 1;
    encoderParams.Parameter[0].Guid = EncoderQuality;
    encoderParams.Parameter[0].Type = EncoderParameterValueTypeLong;
    encoderParams.Parameter[0].NumberOfValues = 1;
    encoderParams.Parameter[0].Value = &longEncodingQuality;
  }

  return reinterpret_cast<Image *>(image)->Save(
    stream,
    &format, 
    encodingQuality ? &encoderParams : nullptr
  );
}

// MARK: - Gdiplus::ImageCodecInfo

SWT_EXTERN SWTGDIPlusStatusCode swt_GdiplusCopyAllImageCodecInfo(SWTGDIPlusImageCodecInfo const ***outInfo, size_t *outCount) {
  // Find out the size of the buffer needed.
  UINT codecCount = 0;
  UINT byteCount = 0;
  auto rGetSize = GetImageEncodersSize(&codecCount, &byteCount);
  if (rGetSize != Ok) {
    return rGetSize;
  }

  // Allocate a buffer of sufficient byte size, then bind the leading bytes
  // to ImageCodecInfo. This leaves some number of trailing bytes unbound to
  // any Swift type.
  auto info = reinterpret_cast<ImageCodecInfo *>(std::malloc(byteCount));
  auto rGetEncoders = Gdiplus::GetImageEncoders(codecCount, byteCount, info);
  if (rGetEncoders != Ok) {
    std::free(info);
    return rGetSize;
  }

  auto result = reinterpret_cast<SWTGDIPlusImageCodecInfo const **>(std::calloc(codecCount, sizeof(SWTGDIPlusImageCodecInfo *)));
  std::transform(info, info + codecCount, result, [] (const auto& info) {
    return reinterpret_cast<const SWTGDIPlusImageCodecInfo *>(&info);
  });
  *outInfo = result;
  *outCount = codecCount;
  return Ok;
}

CLSID swt_GdiplusImageCodecInfoGetCLSID(const SWTGDIPlusImageCodecInfo *info) {
  return reinterpret_cast<const ImageCodecInfo *>(info)->Clsid;
}

const wchar_t *swt_GdiplusImageCodecInfoGetFilenameExtension(const SWTGDIPlusImageCodecInfo *info) {
  return reinterpret_cast<const ImageCodecInfo *>(info)->FilenameExtension;
}
#endif
