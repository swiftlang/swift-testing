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

@_spi(Experimental)
public protocol AttachableAsGDIPlusImage {
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
  /// - Warning: GDI+ objects are [not thread-safe](https://learn.microsoft.com/en-us/windows/win32/procthread/multiple-threads-and-gdi-objects)
  ///   by design. The caller is responsible for guarding against concurrent
  ///   access to the resulting GDI+ image object.
  /// 
  /// - Warning: Do not call this function directly. Instead, call
  ///   ``UnsafeMutablePointer/withGDIPlusImage(for:_:)``.
  static func _withGDIPlusImage<A, R>(
    at imageAddress: UnsafeMutablePointer<Self>,
    for attachment: borrowing Attachment<_AttachableImageWrapper<A>>,
    _ body: (OpaquePointer) throws -> R
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
  ///
  /// - Warning: GDI+ objects are [not thread-safe](https://learn.microsoft.com/en-us/windows/win32/procthread/multiple-threads-and-gdi-objects)
  ///   by design. The caller is responsible for guarding against concurrent
  ///   access to the resulting GDI+ image object.
  func withGDIPlusImage<A, R>(
    for attachment: borrowing Attachment<_AttachableImageWrapper<A>>,
    _ body: (OpaquePointer) throws -> R
  ) throws -> R where A: AttachableAsGDIPlusImage {
    var selfCopy = self
    return try withUnsafeMutablePointer(to: &selfCopy) { imageAddress in
      // Stuff the attachment into a pointer so we can reference it from within
      // the closure we pass to `withGDIPlus(_:)`. (The compiler currently can't
      // reason about the lifetime of a borrowed value passed into a closure.)
      try withUnsafePointer(to: attachment) { attachment in
        try withGDIPlus {
          try Self._withGDIPlusImage(at: imageAddress, for: attachment.pointee, body)
        }
      }
    }
  }
}
#endif
