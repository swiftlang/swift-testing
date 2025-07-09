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
private import _TestingInternals

public struct _AttachableImageWrapper<Image>: Sendable where Image: AttachableAsGDIPlusImage {
  /// The underlying image.
  ///
  /// `CGImage` and `UIImage` are sendable, but `NSImage` is not. `NSImage`
  /// instances can be created from closures that are run at rendering time.
  /// The AppKit cross-import overlay is responsible for ensuring that any
  /// instances of this type it creates hold "safe" `NSImage` instances.
  nonisolated(unsafe) var image: Image

  /// The image format to use when encoding the represented image.
  var imageFormat: AttachableImageFormat?

  init(image: Image, imageFormat: AttachableImageFormat?) {
    self.image = image._makeCopyForAttachment()
    self.imageFormat = imageFormat
  }
}

extension _AttachableImageWrapper: AttachableWrapper {
  public var wrappedValue: Image {
    image
  }

  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try withGDIPlus {
      try image._withGDIPlusImage(for: attachment) { image in
        fatalError("GDI+ Unimplemented \(#function)")
      }
    }
  }
}
#endif
