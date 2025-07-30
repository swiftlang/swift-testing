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
  public static func _withGDIPlusImage<P, R>(
    at address: P,
    for attachment: borrowing Attachment<some AttachableWrapper<P> & ~Copyable>,
    _ body: (OpaquePointer) throws -> R
  ) throws -> R where P: _Pointer, P.Pointee == Self {
    let address = UnsafeMutablePointer<Self>(bitPattern: UInt(bitPattern: address))!
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

  public static func _cleanUpAttachment<P>(at address: P) where P: _Pointer, P.Pointee == Self {
    let address = UnsafeMutablePointer<Self>(bitPattern: UInt(bitPattern: address))!
    DeleteObject(address)
  }
}
#endif
