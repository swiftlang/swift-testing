//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A type representing an error that can occur when attaching an image.
#if SWT_NO_IMAGE_ATTACHMENTS
@available(*, unavailable, message: "Image attachments are not available on this platform.")
#endif
package enum ImageAttachmentError: Error {
#if os(anyAppleOS)
  /// The image could not be converted to an instance of `CGImage`.
  case couldNotCreateCGImage

  /// The image destination could not be created.
  case couldNotCreateImageDestination

  /// The image could not be converted.
  case couldNotConvertImage

  /// The specified content type is not supported by Image I/O.
  case unsupportedImageFormat(_ typeIdentifier: String)
#elseif os(Windows)
  /// A call to `QueryInterface()` failed.
  case queryInterfaceFailed(Any.Type, CLong)

  /// The testing library failed to create a COM object.
  case comObjectCreationFailed(Any.Type, CLong)

  /// An image could not be written.
  case imageWritingFailed(CLong)

  /// The testing library failed to get an in-memory stream's underlying buffer.
  case globalFromStreamFailed(CLong)

  /// A property could not be written to a property bag.
  case propertyBagWritingFailed(String, CLong)

  /// The `HRESULT` value underlying this error.
  fileprivate var hresultValue: HRESULT {
    switch self {
    case let .queryInterfaceFailed(_, result),
      let .comObjectCreationFailed(_, result),
      let .imageWritingFailed(result),
      let .globalFromStreamFailed(result),
      let .propertyBagWritingFailed(_, result):
      return result
    }
  }
#endif
}

#if SWT_NO_IMAGE_ATTACHMENTS
@available(*, unavailable, message: "Image attachments are not available on this platform.")
#endif
extension ImageAttachmentError: CustomStringConvertible {
  package var description: String {
#if os(anyAppleOS)
    switch self {
    case .couldNotCreateCGImage:
      "Could not create the corresponding Core Graphics image."
    case .couldNotCreateImageDestination:
      "Could not create the Core Graphics image destination to encode this image."
    case .couldNotConvertImage:
      "Could not convert the image to the specified format."
    case let .unsupportedImageFormat(typeIdentifier):
      "Could not convert the image to the format '\(typeIdentifier)' because the system does not support it."
    }
#elseif os(Windows)
    let result = "0x\(String(hresultValue, radix: 16))"
    switch self {
    case let .queryInterfaceFailed(type, _):
      return "Could not cast a COM object to type '\(type)' (HRESULT \(result))."
    case let .comObjectCreationFailed(type, _):
      return "Could not create a COM object of type '\(type)' (HRESULT \(result))."
    case .imageWritingFailed:
      return "Could not write the image (HRESULT \(result))."
    case .globalFromStreamFailed:
      return "Could not access the buffer containing the encoded image (HRESULT \(result))."
    case let .propertyBagWritingFailed(name, _):
      return "Could not set the property '\(name)' (HRESULT \(result))."
    }
#else
    swt_unreachable()
#endif
  }
}
