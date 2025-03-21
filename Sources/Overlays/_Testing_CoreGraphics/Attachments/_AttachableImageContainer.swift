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
///    (although in the future we may introduce a "metadata" associated type to
///    `Attachable` that could store that info.)
/// 3. `Attachable` has a requirement with `Self` in non-parameter, non-return
///    position. As far as Swift is concerned, a non-final class cannot satisfy
///    such a requirement, and all image types we care about are non-final
///    classes. Thus, the compiler will steadfastly refuse to allow non-final
///    classes to conform to the `Attachable` protocol. We could get around this
///    by changing the signature of `withUnsafeBytes()` so that the
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
public struct _AttachableImageContainer<Image>: Sendable where Image: AttachableAsCGImage {
  /// The underlying image.
  ///
  /// `CGImage` and `UIImage` are sendable, but `NSImage` is not. `NSImage`
  /// instances can be created from closures that are run at rendering time.
  /// The AppKit cross-import overlay is responsible for ensuring that any
  /// instances of this type it creates hold "safe" `NSImage` instances.
  nonisolated(unsafe) var image: Image

  /// The encoding quality to use when encoding the represented image.
  var encodingQuality: Float

  /// Storage for ``contentType``.
  private var _contentType: (any Sendable)?

  /// The content type to use when encoding the image.
  ///
  /// The testing library uses this property to determine which image format to
  /// encode the associated image as when it is attached to a test.
  ///
  /// If the value of this property does not conform to [`UTType.image`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/image),
  /// the result is undefined.
  @available(_uttypesAPI, *)
  var contentType: UTType {
    get {
      if let contentType = _contentType as? UTType {
        return contentType
      } else {
        return encodingQuality < 1.0 ? .jpeg : .png
      }
    }
    set {
      precondition(
        newValue.conforms(to: .image),
        "An image cannot be attached as an instance of type '\(newValue.identifier)'. Use a type that conforms to 'public.image' instead."
      )
      _contentType = newValue
    }
  }

  /// The content type to use when encoding the image, substituting a concrete
  /// type for `UTType.image`.
  ///
  /// This property is not part of the public interface of the testing library.
  @available(_uttypesAPI, *)
  var computedContentType: UTType {
    if let contentType = _contentType as? UTType, contentType != .image {
      contentType
    } else {
      encodingQuality < 1.0 ? .jpeg : .png
    }
  }

  /// The type identifier (as a `CFString`) corresponding to this instance's
  /// ``computedContentType`` property.
  ///
  /// The value of this property is used by ImageIO when serializing an image.
  ///
  /// This property is not part of the public interface of the testing library.
  /// It is used by ImageIO below.
  var typeIdentifier: CFString {
    if #available(_uttypesAPI, *) {
      computedContentType.identifier as CFString
    } else {
      encodingQuality < 1.0 ? kUTTypeJPEG : kUTTypePNG
    }
  }

  init(image: Image, encodingQuality: Float, contentType: (any Sendable)?) {
    self.image = image._makeCopyForAttachment()
    self.encodingQuality = encodingQuality
    if #available(_uttypesAPI, *), let contentType = contentType as? UTType {
      self.contentType = contentType
    }
  }
}

// MARK: -

extension _AttachableImageContainer: AttachableContainer {
  public var attachableValue: Image {
    image
  }

  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    let data = NSMutableData()

    // Convert the image to a CGImage.
    let attachableCGImage = try image.attachableCGImage

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

  public borrowing func preferredName(for attachment: borrowing Attachment<Self>, basedOn suggestedName: String) -> String {
    if #available(_uttypesAPI, *) {
      return (suggestedName as NSString).appendingPathExtension(for: computedContentType)
    }

    return suggestedName
  }
}
#endif
