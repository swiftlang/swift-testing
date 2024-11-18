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
/// A type representing errors that can occur when attaching an image.
package enum ImageAttachmentError: Error, CustomStringConvertible {
  /// The specified content type did not conform to `.image`.
  case contentTypeDoesNotConformToImage

  /// A `CGContext` could not be created in which to draw the image.
  case couldNotCreateCGContext

  /// The image could not be converted to an instance of `CGImage`.
  case couldNotCreateCGImage

  /// The image destination could not be created.
  case couldNotCreateImageDestination

  /// The image could not be converted.
  case couldNotConvertImage

  package var description: String {
    switch self {
    case .contentTypeDoesNotConformToImage:
      "The specified type does not represent an image format."
    case .couldNotCreateCGContext:
      "Could not create a Core Graphics context to draw in."
    case .couldNotCreateCGImage:
      "Could not create the corresponding Core Graphics image."
    case .couldNotCreateImageDestination:
      "Could not create the Core Graphics image destination to encode this image."
    case .couldNotConvertImage:
      "Could not convert the image to the specified format."
    }
  }
}
#endif
