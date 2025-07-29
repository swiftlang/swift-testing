//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if os(Windows)
@_spi(Experimental) import Testing

import WinSDK
private import _Gdiplus

enum GDIPlusError: Error {
  case status(Gdiplus.Status)
  case hresult(HRESULT)
  case win32Error(DWORD)
  case clsidNotFoundForImageFormat(AttachableImageFormat)
}

func withGDIPlus<R>(_ body: () throws -> R) throws -> R {
  var token = ULONG_PTR(0)
  var input = Gdiplus.GdiplusStartupInput(nil, false, false)
  let rStartup = swt_winsdk_GdiplusStartup(&token, &input, nil)
  guard rStartup == Gdiplus.Ok else {
    throw GDIPlusError.status(rStartup)
  }
  defer {
    swt_winsdk_GdiplusShutdown(token)
  }

  return try body()
}
#endif
