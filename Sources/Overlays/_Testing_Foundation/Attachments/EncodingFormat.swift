//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation)
@_spi(Experimental) import Testing
import Foundation

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
private import UniformTypeIdentifiers
#endif

/// An enumeration describing the encoding formats we support for `Encodable`
/// and `NSSecureCoding` types that conform to `Test.Attachable`.
enum EncodingFormat {
  /// A property list format.
  ///
  /// - Parameters:
  ///   - format: The corresponding property list format.
  case propertyListFormat(_ format: PropertyListSerialization.PropertyListFormat)

  /// The JSON format.
  case json

  /// The encoding format to use by default.
  ///
  /// The specific format this case corresponds to depends on if we are encoding
  /// an `Encodable` value or an `NSSecureCoding` value.
  case `default`

  /// Initialize an instance of this type representing the content type or media
  /// type of the specified attachment.
  ///
  /// - Parameters:
  ///   - attachment: The attachment that will be encoded.
  ///
  /// - Throws: If the attachment's content type or media type is unsupported.
  init(for attachment: borrowing Test.Attachment) throws {
    let ext = (attachment.preferredName as NSString).pathExtension

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
    // If the caller explicitly wants to encode their data as either XML or as a
    // property list, use PropertyListEncoder. Otherwise, we'll fall back to
    // JSONEncoder below.
    if #available(_uttypesAPI, *), let contentType = UTType(filenameExtension: ext) {
      if contentType == .data {
        self = .default
      } else if contentType.conforms(to: .json) {
        self = .json
      } else if contentType.conforms(to: .xml) {
        self = .propertyListFormat(.xml)
      } else if contentType.conforms(to: .binaryPropertyList) || contentType == .propertyList {
        self = .propertyListFormat(.binary)
      } else if contentType.conforms(to: .propertyList) {
        self = .propertyListFormat(.openStep)
      } else {
        let contentTypeDescription = contentType.localizedDescription ?? contentType.identifier
        throw CocoaError(.propertyListWriteInvalid, userInfo: [NSLocalizedDescriptionKey: "The content type '\(contentTypeDescription)' cannot be used to attach an instance of \(type(of: self)) to a test."])
      }
      return
    }
#endif

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
