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

/// A protocol describing images that can be converted to instances of
/// ``Testing/Attachment``.
///
/// This protocol refines ``AttachableByDrawing`` and is used by image types
/// that already contain instances of ``CGImage``.
///
/// This protocol is not part of the public interface of the testing library.
/// External types can conform to ``AttachableByDrawing`` instead.
@_spi(Experimental) @_spi(ForSwiftTestingOnly)
public protocol AttachableAsCGImage: AttachableByDrawing {
  /// An instance of `CGImage` representing this image.
  ///
  /// - Throws: Any error that prevents the creation of an image.
  var attachableCGImage: CGImage { get throws }
}

extension AttachableAsCGImage {
  public var attachmentColorSpace: CGColorSpace {
    guard let colorSpace = (try? attachableCGImage)?.colorSpace else {
      return defaultAttachmentColorSpace
    }
    return colorSpace
  }

  public var attachmentBounds: CGRect {
    guard let image = try? attachableCGImage else {
      return .zero
    }
    return CGRect(x: 0.0, y: 0.0, width: CGFloat(image.width), height: CGFloat(image.height))
  }

  public func draw<A>(in context: CGContext, for attachment: Attachment<A>) throws where A : AttachableContainer, A.AttachableValue : AttachableByDrawing {
    let image = try attachableCGImage
    let bounds = CGRect(x: 0.0, y: 0.0, width: CGFloat(image.width), height: CGFloat(image.height))
    context.draw(image, in: bounds)
  }
}
#endif
