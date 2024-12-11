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

#if canImport(CoreServices_Private)
private import CoreServices_Private
#endif

extension Attachment {
  /// Initialize an instance of this type that encloses the given image.
  ///
  /// - Parameters:
  ///   - attachableValue: The value that will be attached to the output of
  ///     the test run.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the testing library attempts
  ///     to derive a reasonable filename for the attached value.
  ///   - metadata: Optional metadata such as the image format to use when
  ///     encoding `image`. If `nil`, the testing library will infer the format
  ///     and other metadata.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// The following system-provided image types conform to the
  /// ``AttachableAsCGImage`` protocol and can be attached to a test:
  ///
  /// - [`CGImage`](https://developer.apple.com/documentation/coregraphics/cgimage)
  @_spi(Experimental)
  public init<T>(
    _ attachableValue: T,
    named preferredName: String?,
    metadata: ImageAttachmentMetadata? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) where AttachableValue == _AttachableImageWrapper<T> {
    var preferredName = preferredName ?? Self.defaultPreferredName
    var metadata = metadata ?? ImageAttachmentMetadata()

    // Update the preferred name to include an extension appropriate for the
    // given content type. (Note the `else` branch duplicates the logic in
    // `preferredContentType(forEncodingQuality:)` but will go away once our
    // minimum deployment targets include the UniformTypeIdentifiers framework.)
    if #available(_uttypesAPI, *) {
      preferredName = (preferredName as NSString).appendingPathExtension(for: metadata.contentType)
    } else {
#if canImport(CoreServices_Private)
      // The caller can't provide a content type, so we'll pick one for them.
      preferredName = _UTTypeCreateSuggestedFilename(preferredName as CFString, metadata.typeIdentifier)?.takeRetainedValue() ?? preferredName
#endif
    }

    let imageContainer = _AttachableImageWrapper(attachableValue)
    self.init(imageContainer, named: preferredName, metadata: metadata, sourceLocation: sourceLocation)
  }
}
#endif
