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
import Testing
public import Foundation

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// An enumeration describing the encoding formats we support for `Encodable`
/// and `NSSecureCoding` types that conform to `Attachable`.
public enum EncodingFormat: Sendable {
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
  ///   - preferredName: The preferred name of the attachment.
  ///
  /// - Throws: If the attachment's content type or media type is unsupported.
  init?(forPreferredName preferredName: String) throws {
    let ext = (preferredName as NSString).pathExtension
    if ext.isEmpty {
      // No path extension? No problem! Default data.
      return nil
    } else if ext.caseInsensitiveCompare("plist") == .orderedSame {
      self = .propertyListFormat(.binary)
    } else if ext.caseInsensitiveCompare("xml") == .orderedSame {
      self = .propertyListFormat(.xml)
    } else if ext.caseInsensitiveCompare("json") == .orderedSame {
      self = .json
    } else {
#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
      if let encodingFormat = UTType(filenameExtension: ext).flatMap(Self.init(for:)) {
        self = encodingFormat
        return
      }
#endif
      throw CocoaError(.propertyListWriteInvalid, userInfo: [NSLocalizedDescriptionKey: "The path extension '.\(ext)' cannot be used to attach an instance of \(type(of: self)) to a test."])
    }
  }

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
  /// Initialize an instance of this type representing the given content type.
  ///
  /// - Parameters:
  ///   - contentType: The content type of the attachment.
  ///
  /// This initializer returns `nil` if `contentType` does not conform to a
  /// supported encoding format.
  init?(for contentType: UTType) {
    if contentType.conforms(to: .binaryPropertyList) {
      self = .propertyListFormat(.binary)
    } else if contentType.conforms(to: .xmlPropertyList) {
      self = .propertyListFormat(.xml)
    } else if contentType.conforms(to: .json) {
      self = .json
    } else {
      return nil
    }
  }

  /// The content type corresponding to this instance.
  var contentType: UTType {
    switch self {
    case .propertyListFormat(.binary):
      .binaryPropertyList
    case .propertyListFormat(.xml):
      .xmlPropertyList
    case .propertyListFormat:
      .propertyList
    case .json:
      .json
    }
  }
#else
  /// The preferred path extension corresponding to this instance.
  var preferredPathExtension: String {
    switch self {
    case .propertyListFormat:
      "plist"
    case .json:
      "json"
    }
  }
#endif
}
#endif
