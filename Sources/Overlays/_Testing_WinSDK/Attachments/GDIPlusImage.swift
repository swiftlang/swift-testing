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
private import _TestingInternals.GDIPlus

internal import WinSDK

/// A GDI+ image.
///
/// Instances of this type represent GDI+ images (that is, instances of
/// [`Gdiplus.Image`](https://learn.microsoft.com/en-us/windows/win32/api/gdiplusheaders/nl-gdiplusheaders-image)).
@_spi(Experimental)
@unsafe public struct GDIPlusImage: ~Copyable {
  /// The address of the C++ `Gdiplus::Image` instance.
  var imageAddress: OpaquePointer

  private var _deleteWhenDone: Bool

  /// Construct an instance of this type by cloning an existing GDI+ image.
  ///
  /// - Parameters:
  ///   - imageAddress: The address of an existing GDI+ image of type
  ///     [`Gdiplus.Image`](https://learn.microsoft.com/en-us/windows/win32/api/gdiplusheaders/nl-gdiplusheaders-image)).
  ///
  /// This initializer makes a copy of `imageAddress` by calling its[`Clone()`](https://learn.microsoft.com/en-us/windows/win32/api/gdiplusheaders/nf-gdiplusheaders-image-clone)
  /// function. The caller is responsible for ensuring that the resources
  /// backing the resulting image remain valid until it is deinitialized.
  ///
  /// - Important: If `imageAddress` is not a pointer to a GDI+ image, the
  ///   result is undefined.
  public init(unsafe imageAddress: OpaquePointer) {
    self.imageAddress = swt_GdiplusImageClone(imageAddress)
    self._deleteWhenDone = true
  }

  /// Construct an instance of this type by borrowing an existing GDI+ image.
  ///
  /// - Parameters:
  ///   - imageAddress: The address of an existing GDI+ image of type
  ///     [`Gdiplus.Image`](https://learn.microsoft.com/en-us/windows/win32/api/gdiplusheaders/nl-gdiplusheaders-image)).
  ///
  /// The caller is responsible for ensuring that the resources backing the
  /// resulting image remain valid until it is deinitialized.
  ///
  /// - Important: If `imageAddress` is not a pointer to a GDI+ image, the
  ///   result is undefined.
  init(borrowing imageAddress: OpaquePointer) {
    self.imageAddress = imageAddress
    self._deleteWhenDone = false
  }

  deinit {
    if _deleteWhenDone {
      swt_GdiplusImageDelete(imageAddress)
    }
  }
}

extension GDIPlusImage: _AttachableByAddressAsGDIPlusImage {
  public static func _withGDIPlusImage<A, R>(
    at imageAddress: UnsafeMutablePointer<Self>,
    for attachment: borrowing Attachment<_AttachableImageWrapper<A>>,
    _ body: (borrowing UnsafeMutablePointer<GDIPlusImage>) throws -> R
  ) throws -> R where A: AttachableAsGDIPlusImage {
    try body(imageAddress)
  }

  public static func _cleanUpAttachment(at imageAddress: UnsafeMutablePointer<Self>) {
    swt_GdiplusImageDelete(imageAddress.pointee.imageAddress)
  }
}
#endif
