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
extension WinSDK.HICON__: AttachableAsGDIPlusImage {
  public static func _withGDIPlusImage<P, R>(
    at address: P,
    for attachment: borrowing Attachment<some AttachableWrapper<P>>,
    _ body: (OpaquePointer) throws -> R
  ) throws -> R where P: _Pointer, P.Pointee == Self {
    let address = UnsafeMutablePointer<Self>(bitPattern: UInt(bitPattern: address))
    guard let image = swt_winsdk_GdiplusBitmapCreate(address) else {
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
