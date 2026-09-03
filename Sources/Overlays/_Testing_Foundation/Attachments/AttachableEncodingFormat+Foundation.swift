//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
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

/// @Metadata {
///   @Available(Swift, introduced: 6.5)
/// }
extension AttachableEncodingFormat {
  /// Create an instance of this type representing a property list format.
  ///
  /// - Parameters:
  ///   - format: The corresponding property list format.
  ///
  /// - Returns: An instance of this type representing `format`.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public static func propertyListFormat(_ format: PropertyListSerialization.PropertyListFormat) -> Self {
    .init(kind: .propertyListFormat(format.rawValue))
  }

  /// An instance of this type representing the JSON format.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public static var json: Self {
    .init(kind: .json)
  }

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
  /// The content type corresponding to this instance.
  var contentType: UTType {
    switch kind {
    case .propertyListFormat(PropertyListSerialization.PropertyListFormat.binary.rawValue):
      .binaryPropertyList
    case .propertyListFormat(PropertyListSerialization.PropertyListFormat.xml.rawValue):
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
    switch kind {
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
    lazy var pathExtension = (suggestedName as NSString).pathExtension

    // Leave ".xml" as the path extension when explicitly specified.
    if kind == .propertyListFormat(PropertyListSerialization.PropertyListFormat.xml.rawValue),
       pathExtension.caseInsensitiveCompare("xml") == .orderedSame {
      return suggestedName
    }

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
    return (suggestedName as NSString).appendingPathExtension(for: contentType)
#else
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
