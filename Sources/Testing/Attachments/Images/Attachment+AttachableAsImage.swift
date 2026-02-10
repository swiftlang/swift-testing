//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// @Metadata {
///   @Available(Swift, introduced: 6.3)
/// }
#if SWT_NO_IMAGE_ATTACHMENTS
@_unavailableInEmbedded
@available(*, unavailable, message: "Image attachments are not available on this platform.")
#endif
@available(_uttypesAPI, *) // For DocC
extension Attachment {
  /// Initialize an instance of this type that encloses the given image.
  ///
  /// - Parameters:
  ///   - image: The value that will be attached to the output of the test run.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the testing library attempts
  ///     to derive a reasonable filename for the attached value.
  ///   - imageFormat: The image format with which to encode `image`.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// The testing library uses the image format specified by `imageFormat`. Pass
  /// `nil` to let the testing library decide which image format to use. If you
  /// pass `nil`, then the image format that the testing library uses depends on
  /// the path extension you specify in `preferredName`, if any. If you do not
  /// specify a path extension, or if the path extension you specify doesn't
  /// correspond to an image format the operating system knows how to write, the
  /// testing library selects an appropriate image format for you.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.3)
  /// }
  public init<T>(
    _ image: T,
    named preferredName: String? = nil,
    as imageFormat: AttachableImageFormat? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) where AttachableValue: _AttachableImageWrapper<T> & AttachableWrapper {
    let imageWrapper = AttachableValue(image: image, imageFormat: imageFormat)
    self.init(imageWrapper, named: preferredName, sourceLocation: sourceLocation)
  }

  /// Attach an image to the current test.
  ///
  /// - Parameters:
  ///   - image: The value to attach.
  ///   - preferredName: The preferred name of the attachment when writing it to
  ///     a test report or to disk. If `nil`, the testing library attempts to
  ///     derive a reasonable filename for the attached value.
  ///   - imageFormat: The image format with which to encode `image`.
  ///   - sourceLocation: The source location of the call to this function.
  ///
  /// This function creates a new instance of ``Attachment`` wrapping `image`
  /// and immediately attaches it to the current test. The testing library uses
  /// the image format that `imageFormat` specifies. Pass `nil` to let the testing
  /// library select which image format to use. If you pass `nil`, the
  /// image format that the testing library uses depends on the path extension
  /// you specify in `preferredName`, if any. If you don't specify a path
  /// extension, or if the path extension you specify doesn't correspond to an
  /// image format the operating system knows how to write, the testing library
  /// selects an appropriate image format for you.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.3)
  /// }
  public static func record<T>(
    _ image: T,
    named preferredName: String? = nil,
    as imageFormat: AttachableImageFormat? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) where AttachableValue: _AttachableImageWrapper<T> & AttachableWrapper {
    let attachment = Self(image, named: preferredName, as: imageFormat, sourceLocation: sourceLocation)
    Self.record(attachment, sourceLocation: sourceLocation)
  }
}

// MARK: -

#if SWT_NO_IMAGE_ATTACHMENTS
@_unavailableInEmbedded
@available(*, unavailable, message: "Image attachments are not available on this platform.")
#endif
@available(_uttypesAPI, *) // For DocC
extension Attachment where AttachableValue: AttachableWrapper, AttachableValue.Wrapped: AttachableAsImage {
  /// The image format to use when encoding the represented image, if specified.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.3)
  /// }
  @_disfavoredOverload public var imageFormat: AttachableImageFormat? {
    // FIXME: no way to express `where AttachableValue == _AttachableImageWrapper<???>` on a property (see rdar://47559973)
    (attachableValue as? _AttachableImageWrapper<AttachableValue.Wrapped>)?.imageFormat
  }
}
