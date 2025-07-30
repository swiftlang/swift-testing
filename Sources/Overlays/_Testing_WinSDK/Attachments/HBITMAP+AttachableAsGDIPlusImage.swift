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
private import _TestingInternals.GDIPlus

public import WinSDK

@_spi(Experimental)
extension HBITMAP__: _AttachableByAddressAsGDIPlusImage {
  public static func _withGDIPlusImage<A, R>(
    at imageAddress: UnsafeMutablePointer<Self>,
    for attachment: borrowing Attachment<_AttachableImageWrapper<A>>,
    _ body: (borrowing UnsafeMutablePointer<GDIPlusImage>) throws -> R
  ) throws -> R where A: AttachableAsGDIPlusImage {
    let image = swt_GdiplusImageFromHBITMAP(imageAddress, nil)
    defer {
      swt_GdiplusImageDelete(image)
    }
    return try withExtendedLifetime(self) {
      var image: GDIPlusImage = GDIPlusImage(borrowing: image)
      return try body(&image)
    }
  }

  public static func _cleanUpAttachment(at imageAddress: UnsafeMutablePointer<Self>) {
    DeleteObject(imageAddress)
  }
}
#endif
