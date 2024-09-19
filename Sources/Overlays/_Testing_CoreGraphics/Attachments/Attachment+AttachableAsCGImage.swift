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

public import UniformTypeIdentifiers

extension Attachment {
  /// Initialize an instance of this type that encloses the given image.
  ///
  /// - Parameters:
  ///   - attachableValue: The value that will be attached to the output of
  ///     the test run.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the testing library attempts
  ///     to derive a reasonable filename for the attached value.
  ///   - contentType: The image format with which to encode `attachableValue`.
  ///     If this type does not conform to [`UTType.image`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/image),
  ///     the result is undefined. Pass `nil` to let the testing library decide
  ///     which image format to use.
  ///   - encodingQuality: The encoding quality to use when encoding the image.
  ///     If the image format used for encoding (specified by the `contentType`
  ///     argument) does not support variable-quality encoding, the value of
  ///     this argument is ignored.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// This is the designated initializer for this type when attaching an image
  /// that conforms to ``AttachableAsCGImage``.
  fileprivate init<T>(
    attachableValue: T,
    named preferredName: String?,
    as contentType: (any Sendable)?,
    encodingQuality: Float,
    sourceLocation: SourceLocation
  ) where AttachableValue == _AttachableImageContainer<T> {
    var imageContainer = _AttachableImageContainer(image: attachableValue, encodingQuality: encodingQuality)

    // Update the preferred name to include an extension appropriate for the
    // given content type. (Note the `else` branch duplicates the logic in
    // `preferredContentType(forEncodingQuality:)` but will go away once our
    // minimum deployment targets include the UniformTypeIdentifiers framework.)
    var preferredName = preferredName ?? Self.defaultPreferredName
    if #available(_uttypesAPI, *) {
      if let contentType = contentType as? UTType, contentType.impliesSpecificImageType {
        preferredName = (preferredName as NSString).appendingPathExtension(for: contentType)
        imageContainer.contentType = contentType
      } else {
        let contentType = UTType.preferred(forEncodingQuality: encodingQuality)
        preferredName = (preferredName as NSString).appendingPathExtension(for: contentType)
      }
    } else {
      let ext = if encodingQuality < 1.0 {
        "jpg"
      } else {
        "png"
      }
      preferredName = ((preferredName as NSString).deletingPathExtension as NSString).appendingPathExtension(ext) ?? preferredName
    }

    self.init(imageContainer, named: preferredName, sourceLocation: sourceLocation)
  }

  /// Initialize an instance of this type that encloses the given image.
  ///
  /// - Parameters:
  ///   - attachableValue: The value that will be attached to the output of
  ///     the test run.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the testing library attempts
  ///     to derive a reasonable filename for the attached value.
  ///   - contentType: The image format with which to encode `attachableValue`.
  ///     If this type does not conform to [`UTType.image`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/image),
  ///     the result is undefined. Pass `nil` to let the testing library decide
  ///     which image format to use.
  ///   - encodingQuality: The encoding quality to use when encoding the image.
  ///     If the image format used for encoding (specified by the `contentType`
  ///     argument) does not support variable-quality encoding, the value of
  ///     this argument is ignored.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// The following system-provided image types conform to the
  /// ``AttachableAsCGImage`` protocol and can be attached to a test:
  ///
  /// - [`CGImage`](https://developer.apple.com/documentation/coregraphics/cgimage)
  /// - [`CIImage`](https://developer.apple.com/documentation/coreimage/ciimage)
  /// - [`NSImage`](https://developer.apple.com/documentation/appkit/nsimage)
  ///   (macOS)
  /// - [`UIImage`](https://developer.apple.com/documentation/uikit/uiimage)
  ///   (iOS, watchOS, tvOS, visionOS, and Mac Catalyst)
  /// - [`XCUIScreenshot`](https://developer.apple.com/documentation/xctest/xcuiscreenshot)
  @_spi(Experimental)
  @available(_uttypesAPI, *)
  public init<T>(
    _ attachableValue: T,
    named preferredName: String? = nil,
    as contentType: UTType?,
    encodingQuality: Float = 1.0,
    sourceLocation: SourceLocation = #_sourceLocation
  ) where AttachableValue == _AttachableImageContainer<T> {
    self.init(attachableValue: attachableValue, named: preferredName, as: contentType, encodingQuality: encodingQuality, sourceLocation: sourceLocation)
  }

  /// Initialize an instance of this type that encloses the given image.
  ///
  /// - Parameters:
  ///   - attachableValue: The value that will be attached to the output of
  ///     the test run.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the testing library attempts
  ///     to derive a reasonable filename for the attached value.
  ///   - encodingQuality: The encoding quality to use when encoding the image.
  ///     If the image format used for encoding (specified by the `contentType`
  ///     argument) does not support variable-quality encoding, the value of
  ///     this argument is ignored.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// The following system-provided image types conform to the
  /// ``AttachableAsCGImage`` protocol and can be attached to a test:
  ///
  /// - [`CGImage`](https://developer.apple.com/documentation/coregraphics/cgimage)
  /// - [`CIImage`](https://developer.apple.com/documentation/coreimage/ciimage)
  /// - [`NSImage`](https://developer.apple.com/documentation/appkit/nsimage)
  ///   (macOS)
  /// - [`UIImage`](https://developer.apple.com/documentation/uikit/uiimage)
  ///   (iOS, watchOS, tvOS, visionOS, and Mac Catalyst)
  /// - [`XCUIScreenshot`](https://developer.apple.com/documentation/xctest/xcuiscreenshot)
  @_spi(Experimental)
  public init<T>(
    _ attachableValue: T,
    named preferredName: String? = nil,
    encodingQuality: Float = 1.0,
    sourceLocation: SourceLocation = #_sourceLocation
  ) where AttachableValue == _AttachableImageContainer<T> {
    self.init(attachableValue: attachableValue, named: preferredName, as: nil, encodingQuality: encodingQuality, sourceLocation: sourceLocation)
  }
}
#endif
