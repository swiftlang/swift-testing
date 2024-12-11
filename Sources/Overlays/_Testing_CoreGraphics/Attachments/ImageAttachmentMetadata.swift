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

public import UniformTypeIdentifiers

/// A type defining metadata used when attaching an image to a test.
///
/// The following system-provided image types can be attached to a test:
///
/// - [`CGImage`](https://developer.apple.com/documentation/coregraphics/cgimage)
@_spi(Experimental)
public struct ImageAttachmentMetadata: Sendable {
  /// The encoding quality to use when encoding the represented image.
  ///
  /// If the image format used for encoding (specified by the ``contentType``
  /// property) does not support variable-quality encoding, the value of this
  /// property is ignored.
  public var encodingQuality: Float

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
      lazy var newValueDescription = newValue.localizedDescription ?? newValue.identifier
      precondition(
        newValue.conforms(to: .image),
        "An image cannot be attached as an instance of type '\(newValueDescription)'. Use a type that conforms to 'public.image' instead."
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

  public init(encodingQuality: Float = 1.0) {
    self.encodingQuality = encodingQuality
  }

  @available(_uttypesAPI, *)
  public init(encodingQuality: Float = 1.0, contentType: UTType) {
    self.encodingQuality = encodingQuality
    self.contentType = contentType
  }
}
#endif
