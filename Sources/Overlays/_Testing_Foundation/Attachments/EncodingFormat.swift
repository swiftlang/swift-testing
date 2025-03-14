//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_FOUNDATION && canImport(Foundation)
@_spi(Experimental) import Testing
import Foundation

/// An enumeration describing the encoding formats we support for `Encodable`
/// and `NSSecureCoding` types that conform to `Attachable`.
enum EncodingFormat {
  /// The encoding format to use by default.
  ///
  /// The specific format this case corresponds to depends on if we are encoding
  /// an `Encodable` value or an `NSSecureCoding` value.
  case `default`

  /// A property list format.
  ///
  /// - Parameters:
  ///   - format: The corresponding property list format.
  case propertyListFormat(_ format: PropertyListSerialization.PropertyListFormat)

  /// The JSON format.
  case json

  /// Initialize an instance of this type representing the content type or media
  /// type of the specified attachment.
  ///
  /// - Parameters:
  ///   - attachment: The attachment that will be encoded.
  ///
  /// - Throws: If the attachment's content type or media type is unsupported.
  init(for attachment: borrowing Attachment<some Attachable>) throws {
    let ext = (attachment.preferredName as NSString).pathExtension
    if ext.isEmpty {
      // No path extension? No problem! Default data.
      self = .default
    } else if ext.caseInsensitiveCompare("plist") == .orderedSame {
      self = .propertyListFormat(.binary)
    } else if ext.caseInsensitiveCompare("xml") == .orderedSame {
      self = .propertyListFormat(.xml)
    } else if ext.caseInsensitiveCompare("json") == .orderedSame {
      self = .json
    } else {
      throw CocoaError(.propertyListWriteInvalid, userInfo: [NSLocalizedDescriptionKey: "The path extension '.\(ext)' cannot be used to attach an instance of \(type(of: self)) to a test."])
    }
  }
}
#endif
