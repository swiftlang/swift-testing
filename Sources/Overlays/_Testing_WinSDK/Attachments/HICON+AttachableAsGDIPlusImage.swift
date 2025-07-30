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
extension HICON__: AttachableAsGDIPlusImage {
  public static func _withGDIPlusImage<R>(
    at address: UnsafeMutablePointer<Self>,
    for attachment: borrowing Attachment<_AttachableImageWrapper<Self>>,
    _ body: (OpaquePointer) throws -> R
  ) throws -> R {
    guard let bitmap = swt_GdiplusBitmapFromHICON(address) else {
      throw GDIPlusError.status(Gdiplus.GenericError)
    }
    defer {
      swt_GdiplusBitmapDelete(bitmap)
    }
    return try withExtendedLifetime(self) {
      try body(bitmap)
    }
  }

  public static func _cleanUpAttachment(at address: UnsafeMutablePointer<Self>) {
    let address = UnsafeMutablePointer<Self>(bitPattern: UInt(bitPattern: address))!
    DeleteObject(address)
  }
}
#endif
