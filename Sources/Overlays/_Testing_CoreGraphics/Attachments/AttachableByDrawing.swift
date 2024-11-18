//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && canImport(CoreGraphics)
@_spi(Experimental) public import Testing
public import CoreGraphics
private import ImageIO

/// A protocol describing values that can be converted to instances of
/// ``Testing/Attachment`` by drawing them in Core Graphics contexts.
///
/// Instances of types conforming to this protocol do not themselves conform to
/// ``Testing/Attachable``. Instead, the testing library provides additional
/// initializers on ``Testing/Attachment`` that take instances of such types and
/// handle converting them to image data when needed.
///
/// The following system-provided image types conform to this protocol and can
/// be attached to a test:
///
/// - [`CGImage`](https://developer.apple.com/documentation/coregraphics/cgimage)
///
/// If a type contains a pre-rendered instance of [`CGImage`](https://developer.apple.com/documentation/coregraphics/cgimage),
/// it is more efficient to attach that image directly rather than making the
/// type conform to this protocol.
@_spi(Experimental)
public protocol AttachableByDrawing {
  /// The bounds of this value in points when drawn in a Core Graphics context.
  ///
  /// The origin of this rectangle should usually be `(0.0, 0.0)`. The testing
  /// library automatically translates the transformation matrix of the Core
  /// Graphics context passed to ``draw(for:in)`` so that drawing at the origin
  /// of this rectangle will draw at the origin of the context.
  ///
  /// The testing library also handles the scale factor of the Core Graphics
  /// context for you, so you do not need to rescale this rectangle; assume a
  /// scale factor of `1.0`.
  var attachmentBounds: CGRect { get }

  /// The color space to use to render this value in a Core Graphics context.
  ///
  /// The value of this property should match the source's color space to avoid
  /// unnecessary conversion during serialization. The default value of this
  /// property is an implementation-defined RGB color space unless this value's
  /// type also conforms to ``AttachableAsCGImage``, in which case it equals the
  /// color space of the instance's ``attachableCGImage`` property.
  var attachmentColorSpace: CGColorSpace { get }

  /// Draw this value in the specified Core Graphics context.
  ///
  /// - Parameters:
  ///   - context: The context in which to draw this value.
  ///   - attachment: The attachment that is requesting the value be drawn (that
  ///     is, the attachment containing this instance.) Due to technical
  ///     constraints of the Swift programming language, this attachment is
  ///     generic, but its attachable value is equal to this value.
  ///
  /// - Throws: Any error that prevents drawing this image in `context`.
  ///
  /// The testing library calls this function when it is ready to serialize this
  /// value to a graphics format such as PNG. The implementation should draw the
  /// value at the origin point of ``attachmentBounds``.
  func draw<A>(in context: CGContext, for attachment: Attachment<A>) throws where A: AttachableContainer, A.AttachableValue: AttachableByDrawing

  /// The orientation of the image.
  ///
  /// The value of this property is the raw value of an instance of
  /// `CGImagePropertyOrientation`. The default value of this property is
  /// `.up`.
  ///
  /// This property is not part of the public interface of the testing
  /// library. It may be removed in a future update.
  var _attachmentOrientation: UInt32 { get }

  /// The scale factor of this value when drawn in a Core Graphics context.
  ///
  /// The value of this property is typically greater than `1.0` when an image
  /// originates from a Retina Display screenshot or similar. The default value
  /// of this property is `1.0`.
  ///
  /// This property is not part of the public interface of the testing
  /// library. It may be removed in a future update.
  var _attachmentScaleFactor: CGFloat { get }

  /// Make a copy of this instance to pass to an attachment.
  ///
  /// - Returns: A copy of `self`, or `self` if no copy is needed.
  ///
  /// Several system image types do not conform to `Sendable`; use this
  /// function to make copies of such images that will not be shared outside
  /// of an attachment and so can be generally safely stored.
  ///
  /// The default implementation of this function when `Self` conforms to
  /// `Sendable` simply returns `self`.
  ///
  /// This function is not part of the public interface of the testing library.
  /// It may be removed in a future update.
  func _makeCopyForAttachment() -> Self
}

/// The default color space to use if a type that conforms to
/// ``AttachableByDrawing`` does not specify one.
let defaultAttachmentColorSpace = CGColorSpaceCreateDeviceRGB()

extension AttachableByDrawing {
  public var attachmentColorSpace: CGColorSpace {
    defaultAttachmentColorSpace
  }

  public var _attachmentOrientation: UInt32 {
    CGImagePropertyOrientation.up.rawValue
  }

  public var _attachmentScaleFactor: CGFloat {
    1.0
  }

  /// Make an instance of `CGImage` representing this value.
  ///
  /// - Parameters:
  ///   - attachment: The attachment that is requesting the value be drawn (that
  ///     is, the attachment containing this instance.)
  ///
  /// - Throws: Any error that prevents creating this image.
  func makeCGImage<A>(for attachment: Attachment<A>) throws -> CGImage where A: AttachableContainer, A.AttachableValue: AttachableByDrawing {
    if let image = self as? any AttachableAsCGImage {
      return try image.attachableCGImage
    } else {
      let bounds = attachmentBounds
      let colorSpace = attachmentColorSpace
      let scaleFactor = _attachmentScaleFactor
      let bitmapInfo = CGBitmapInfo.byteOrderDefault.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

      let context = CGContext(
        data: nil,
        width: Int(ceil(bounds.width * scaleFactor)),
        height: Int(ceil(bounds.height * scaleFactor)),
        bitsPerComponent: 8,
        bytesPerRow: Int(ceil(bounds.width * scaleFactor)) * (colorSpace.numberOfComponents + 1),
        space: colorSpace,
        bitmapInfo: bitmapInfo
      )
      guard let context else {
        throw ImageAttachmentError.couldNotCreateCGContext
      }

      var transform = CGAffineTransform.identity
      transform = transform.translatedBy(x: -bounds.minX, y: -bounds.minY)
      transform = transform.scaledBy(x: scaleFactor, y: scaleFactor)
      context.concatenate(transform)

      try draw(in: context, for: attachment)

      guard let cgImage = context.makeImage() else {
        throw ImageAttachmentError.couldNotCreateCGImage
      }
      return cgImage
    }

  }
}

extension AttachableByDrawing where Self: Sendable {
  public func _makeCopyForAttachment() -> Self {
    self
  }
}
#endif
