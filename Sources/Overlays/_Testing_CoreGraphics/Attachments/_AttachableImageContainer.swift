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
private import CoreGraphics

private import ImageIO
import UniformTypeIdentifiers

/// ## Why can't images directly conform to Attachable?
///
/// Three reasons:
///
/// 1. Several image classes are not marked `Sendable`, which means that as far
///    as Swift is concerned, they cannot be safely passed to Swift Testing's
///    event handler (primarily because `Event` is `Sendable`.) So we would have
///    to eagerly serialize them, which is unnecessarily expensive if we know
///    they're actually concurrency-safe.
/// 2. We would have no place to store metadata such as the encoding quality
/// 	 (although in the future we may introduce a "metadata" associated type to
///    `Attachable` that could store that info.)
/// 3. `Attachable` has a requirement with `Self` in non-parameter, non-return
///    position. As far as Swift is concerned, a non-final class cannot satisfy
///    such a requirement, and all image types we care about are non-final
///    classes. Thus, the compiler will steadfastly refuse to allow non-final
///    classes to conform to the `Attachable` protocol. We could get around this
///    by changing the signature of `withUnsafeBufferPointer()` so that the
///    generic parameter to `Attachment` is not `Self`, but that would defeat
///    much of the purpose of making `Attachment` generic in the first place.
///    (And no, the language does not let us write `where T: Self` anywhere
///    useful.)

/// A wrapper type for image types such as `CGImage` and `NSImage` that can be
/// attached indirectly.
///
/// You do not need to use this type directly. Instead, initialize an instance
/// of ``Attachment`` using an instance of an image type that conforms to
/// ``AttachableAsCGImage``. The following system-provided image types conform
/// to the ``AttachableAsCGImage`` protocol and can be attached to a test:
///
/// - [`CGImage`](https://developer.apple.com/documentation/coregraphics/cgimage)
@_spi(Experimental)
public struct _AttachableImageContainer<ImageClass>: Sendable where ImageClass: AttachableByDrawing {
  /// The underlying image.
  ///
  /// `CGImage` and `UIImage` are sendable, but `NSImage` is not. `NSImage`
  /// instances can be created from closures that are run at rendering time.
  /// The AppKit cross-import overlay is responsible for ensuring that any
  /// instances of this type it creates hold "safe" `NSImage` instances.
  nonisolated(unsafe) var image: ImageClass

  /// The encoding quality to use when encoding the represented image.
  public var encodingQuality: Float

  /// Storage for ``contentType``.
  private var _contentType: (any Sendable)?

  /// The content type to use when encoding the image.
  ///
  /// This property should eventually move up to ``Attachment``. It is not part
  /// of the public interface of the testing library.
  @available(_uttypesAPI, *)
  var contentType: UTType? {
    get {
      _contentType as? UTType
    }
    set {
      _contentType = newValue
    }
  }

  init(image: ImageClass, encodingQuality: Float) {
    self.image = image._makeCopyForAttachment()
    self.encodingQuality = encodingQuality
  }
}

// MARK: -

@available(_uttypesAPI, *)
extension UTType {
  /// Determine the preferred content type to encode this image as for a given
  /// encoding quality.
  ///
  /// - Parameters:
  ///   - encodingQuality: The encoding quality to use when encoding the image.
  ///
  /// - Returns: The type to encode this image as.
  static func preferred(forEncodingQuality encodingQuality: Float) -> Self {
    // If the caller wants lossy encoding, use JPEG.
    if encodingQuality < 1.0 {
      return .jpeg
    }

    // Lossless encoding implies PNG.
    return .png
  }
}

extension _AttachableImageContainer: AttachableContainer {
  public var attachableValue: ImageClass {
    image
  }

  public func withUnsafeBufferPointer<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    let data = NSMutableData()

    // Convert the image to a CGImage.
    let attachableCGImage = try image.makeCGImage(for: attachment)

    // Get the type to encode as. (Note the `else` branches duplicate the logic
    // in `preferredContentType(forEncodingQuality:)` but will go away once our
    // minimum deployment targets include the UniformTypeIdentifiers framework.)
    let typeIdentifier: CFString
    if #available(_uttypesAPI, *), let contentType {
      guard contentType.conforms(to: .image) else {
        throw ImageAttachmentError.contentTypeDoesNotConformToImage
      }
      typeIdentifier = contentType.identifier as CFString
    } else if encodingQuality < 1.0 {
      typeIdentifier = kUTTypeJPEG
    } else {
      typeIdentifier = kUTTypePNG
    }

    // Create the image destination.
    guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, typeIdentifier, 1, nil) else {
      throw ImageAttachmentError.couldNotCreateImageDestination
    }

    // Configure the properties of the image conversion operation.
    let orientation = image._attachmentOrientation
    let scaleFactor = image._attachmentScaleFactor
    let properties: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: CGFloat(encodingQuality),
      kCGImagePropertyOrientation: orientation,
      kCGImagePropertyDPIWidth: 72.0 * scaleFactor,
      kCGImagePropertyDPIHeight: 72.0 * scaleFactor,
    ]

    // Perform the image conversion.
    CGImageDestinationAddImage(dest, attachableCGImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(dest) else {
      throw ImageAttachmentError.couldNotConvertImage
    }

    // Pass the bits of the image out to the body. Note that we have an
    // NSMutableData here so we have to use slightly different API than we would
    // with an instance of Data.
    return try withExtendedLifetime(data) {
      try body(UnsafeRawBufferPointer(start: data.bytes, count: data.length))
    }
  }
}
#endif
