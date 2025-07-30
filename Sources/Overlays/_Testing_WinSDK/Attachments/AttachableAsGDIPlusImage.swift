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

/// A protocol describing images that can be converted to instances of
/// ``Testing/Attachment``.
///
/// Instances of types conforming to this protocol do not themselves conform to
/// ``Testing/Attachable``. Instead, the testing library provides additional
/// initializers on ``Testing/Attachment`` that take instances of such types and
/// handle converting them to image data when needed.
///
/// The following system-provided image types conform to this protocol and can
/// be attached to a test:
///
/// - [`HBITMAP`](https://learn.microsoft.com/en-us/windows/win32/gdi/bitmaps)
/// - [`HICON`](https://learn.microsoft.com/en-us/windows/win32/menurc/icons)
///
/// You do not generally need to add your own conformances to this protocol. If
/// you have an image in another format that needs to be attached to a test,
/// first convert it to an instance of one of the types above.
@_spi(Experimental)
public protocol _AttachableByAddressAsGDIPlusImage: ~Copyable {
  /// Call a function and pass a GDI+ image representing this instance to it.
  ///
  /// - Parameters:
  ///   - imageAddress: The address of the instance of this type.
  ///   - attachment: The attachment that is requesting an image (that is, the
  ///     attachment containing this instance.)
  ///   - body: A function to call. A copy of this instance converted to a GDI+
  ///     image is passed to it.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`, or any error that prevented the
  ///   creation of the buffer.
  /// 
  /// The testing library automatically calls `GdiplusStartup()` and
  /// `GdiplusShutdown()` before and after calling this function. This function
  /// can therefore assume that GDI+ is correclty configured on the current
  /// thread when it is called.
  ///
  /// - Warning: Do not call this function directly. Instead, call
  ///   ``AttachableAsGDIPlusImage/withGDIPlusImage(for:_:)``.
  static func _withGDIPlusImage<A, R>(
    at imageAddress: UnsafeMutablePointer<Self>,
    for attachment: borrowing Attachment<_AttachableImageWrapper<A>>,
    _ body: (borrowing UnsafeMutablePointer<GDIPlusImage>) throws -> R
  ) throws -> R where A: AttachableAsGDIPlusImage

  /// Clean up any resources at the given address.
  /// 
  /// - Parameters:
  ///   - imageAddress: The address of the instance of this type.
  /// 
  /// The implementation of this function cleans up any resources (such as
  /// handles or COM objects) at `imageAddress`. This function is invoked
  /// automatically by `_AttachableImageWrapper` when it is deinitialized.
  /// 
  /// - Warning: Do not call this function directly.
  static func _cleanUpAttachment(at imageAddress: UnsafeMutablePointer<Self>)
}

/// A protocol describing images that can be converted to instances of
/// ``Testing/Attachment``.
///
/// Instances of types conforming to this protocol do not themselves conform to
/// ``Testing/Attachable``. Instead, the testing library provides additional
/// initializers on ``Testing/Attachment`` that take instances of such types and
/// handle converting them to image data when needed.
///
/// The following system-provided image types conform to this protocol and can
/// be attached to a test:
///
/// - [`HBITMAP`](https://learn.microsoft.com/en-us/windows/win32/gdi/bitmaps)
/// - [`HICON`](https://learn.microsoft.com/en-us/windows/win32/menurc/icons)
///
/// You do not generally need to add your own conformances to this protocol. If
/// you have an image in another format that needs to be attached to a test,
/// first convert it to an instance of one of the types above.
@_spi(Experimental)
public protocol AttachableAsGDIPlusImage {
  /// Call a function and pass a GDI+ image representing this instance to it.
  ///
  /// - Parameters:
  ///   - attachment: The attachment that is requesting an image (that is, the
  ///     attachment containing this instance.)
  ///   - body: A function to call. A copy of this instance converted to a GDI+
  ///     image is passed to it.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`, or any error that prevented the
  ///   creation of the buffer.
  /// 
  /// The testing library automatically calls `GdiplusStartup()` and
  /// `GdiplusShutdown()` before and after calling this function. This function
  /// can therefore assume that GDI+ is correclty configured on the current
  /// thread when it is called.
  ///
  /// - Warning: Do not call this function directly. Instead, call
  ///   ``UnsafeMutablePointer/withGDIPlusImage(for:_:)``.
  func _withGDIPlusImage<A, R>(
    for attachment: borrowing Attachment<_AttachableImageWrapper<A>>,
    _ body: (borrowing UnsafeMutablePointer<GDIPlusImage>) throws -> R
  ) throws -> R where A: AttachableAsGDIPlusImage

  /// Clean up any resources at the given address.
  /// 
  /// - Parameters:
  ///   - imageAddress: The address of the instance of this type.
  /// 
  /// The implementation of this function cleans up any resources (such as
  /// handles or COM objects) at `imageAddress`. This function is invoked
  /// automatically by `_AttachableImageWrapper` when it is deinitialized.
  /// 
  /// - Warning: Do not call this function directly.
  func _cleanUpAttachment()
}

extension AttachableAsGDIPlusImage {
  /// Call a function and pass a GDI+ image representing this instance to it.
  ///
  /// - Parameters:
  ///   - attachment: The attachment that is requesting an image (that is, the
  ///     attachment containing this instance.)
  ///   - body: A function to call. A copy of this instance converted to a GDI+
  ///     image is passed to it.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`, or any error that prevented the
  ///   creation of the buffer.
  ///
  /// This function is a convenience wrapper around `_withGDIPlusImage()` that
  /// calls `GdiplusStartup()` and `GdiplusShutdown()` at the appropriate times.
  func withGDIPlusImage<A, R>(
    for attachment: borrowing Attachment<_AttachableImageWrapper<A>>,
    _ body: (borrowing UnsafeMutablePointer<GDIPlusImage>) throws -> R
  ) throws -> R where A: AttachableAsGDIPlusImage {
    // Stuff the attachment into a pointer so we can reference it from within
    // the closure we pass to `withGDIPlus(_:)`. (The compiler currently can't
    // reason about the lifetime of a borrowed value passed into a closure.)
    try withUnsafePointer(to: attachment) { attachment in
      try withGDIPlus {
        try _withGDIPlusImage(for: attachment.pointee, body)
      }
    }
  }
}
#endif
