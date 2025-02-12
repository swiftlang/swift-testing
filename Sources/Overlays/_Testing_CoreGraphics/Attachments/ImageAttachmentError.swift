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
/// A type representing an error that can occur when attaching an image.
enum ImageAttachmentError: Error, CustomStringConvertible {
  /// The image could not be converted to an instance of `CGImage`.
  case couldNotCreateCGImage

  /// The image destination could not be created.
  case couldNotCreateImageDestination

  /// The image could not be converted.
  case couldNotConvertImage

  public var description: String {
    switch self {
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
