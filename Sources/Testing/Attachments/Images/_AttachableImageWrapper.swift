//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A wrapper type for images that can be indirectly attached to a test.
#if SWT_NO_IMAGE_ATTACHMENTS
@_unavailableInEmbedded
@available(*, unavailable, message: "Image attachments are not available on this platform.")
#endif
@available(_uttypesAPI, *)
public final class _AttachableImageWrapper<Image>: Sendable where Image: AttachableAsImage {
  /// The underlying image.
  public nonisolated(unsafe) let wrappedValue: Image

  /// The image format to use when encoding the represented image.
  package let imageFormat: AttachableImageFormat?

  init(image: Image, imageFormat: AttachableImageFormat?) {
    self.wrappedValue = image._copyAttachableValue()
    self.imageFormat = imageFormat
  }

  deinit {
    wrappedValue._deinitializeAttachableValue()
  }
}
