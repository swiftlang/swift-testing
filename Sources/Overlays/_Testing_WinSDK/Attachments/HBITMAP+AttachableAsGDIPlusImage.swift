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
@_spi(Experimental) public import Testing

// FIXME: swiftc gets confused about the _Gdiplus module using types from WinSDK; needs to be part of WinSDK directly
public import WinSDK
private import _Gdiplus

@_spi(Experimental)
extension WinSDK.HBITMAP: AttachableAsGDIPlusImage {
  public func _withGDIPlusImage<R>(
    for attachment: borrowing Attachment<some AttachableWrapper<Self>>,
    _ body: (OpaquePointer) throws -> R
  ) throws -> R {
    guard let image = swt_winsdk_GdiplusBitmapCreate(self, nil) else {
      throw GDIPlusError.status(Gdiplus.GenericError)
    }
    defer {
      swt_winsdk_GdiplusImageDelete(image)
    }
    return try withExtendedLifetime(self) {
      try body(image)
    }
  }
}
#endif
