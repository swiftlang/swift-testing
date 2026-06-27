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

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
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

  /// Construct an attachment name based on a suggested name and this encoding
  /// format.
  ///
  /// - Parameters:
  ///   - suggestedName: A suggested name to use as the basis of the preferred
  ///     name.
  ///
  /// - Returns: The preferred name for an attachment. The result may or may not
  ///   equal `suggestedName`.
  func preferredName(basedOn suggestedName: String) -> String {
#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
    return (suggestedName as NSString).appendingPathExtension(for: contentType)
#else
    let pathExtension = (suggestedName as NSString).pathExtension
    guard pathExtension.isEmpty else {
      // The developer specified a path extension. This path extension may
      // reflect some file format that uses Encodable for serialization, so use
      // it verbatim.
      return suggestedName
    }
    return (suggestedName as NSString).appendingPathExtension(preferredPathExtension) ?? suggestedName
#endif
  }
}
#endif
