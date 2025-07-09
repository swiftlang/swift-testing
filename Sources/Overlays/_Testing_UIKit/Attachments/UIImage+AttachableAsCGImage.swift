//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && canImport(UIKit)
public import UIKit
@_spi(Experimental) public import _Testing_CoreGraphics
@_spi(Experimental) private import _Testing_CoreImage

private import ImageIO

@_spi(Experimental)
extension UIImage: AttachableAsCGImage {
  public var attachableCGImage: CGImage {
    get throws {
      if let cgImage {
        return cgImage
      } else if let ciImage {
        return try ciImage.attachableCGImage
      }
      throw ImageAttachmentError.couldNotCreateCGImage
    }
  }

  public var _attachmentOrientation: UInt32 {
    let result: CGImagePropertyOrientation = switch imageOrientation {
    case .up: .up
    case .down: .down
    case .left: .left
    case .right: .right
    case .upMirrored: .upMirrored
    case .downMirrored: .downMirrored
    case .leftMirrored: .leftMirrored
    case .rightMirrored: .rightMirrored
    @unknown default: .up
    }
    return result.rawValue
  }

  public var _attachmentScaleFactor: CGFloat {
    scale
  }
}
#endif
