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

/// An enumeration describing the encoding formats that you can use when
/// attaching a value that conforms to [`Encodable`](https://developer.apple.com/documentation/swift/encodable).
///
/// Pass an instance of this type to ``Testing/Attachment/init(encoding:as:named:sourceLocation:)``
/// to specify what encoder and format to use when the testing library saves the
/// resulting attachment.
///
/// If you want to attach a value that conforms to [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding),
/// use [`PropertyListFormat`](https://developer.apple.com/documentation/foundation/propertylistserialization/propertylistformat)
/// instead.
@_spi(Experimental)
public struct AttachableEncodingFormat: Sendable {
  /// An enumeration describing the various kinds of encoding format the testing
  /// library supports.
  enum Kind: Sendable {
    /// A property list format.
    ///
    /// - Parameters:
    ///   - format: The corresponding property list format.
    case propertyListFormat(_ format: PropertyListSerialization.PropertyListFormat)

    /// The JSON format.
    case json
  }

  /// The kind of encoding format represented by this instance.
  var kind: Kind

  /// Create an instance of this type representing a property list format.
  ///
  /// - Parameters:
  ///   - format: The corresponding property list format.
  ///
  /// - Returns: An instance of this type representing `format`.
  public static func propertyListFormat(_ format: PropertyListSerialization.PropertyListFormat) -> Self {
    .init(kind: .propertyListFormat(format))
  }

  /// An instance of this type representing the JSON format.
  public static var json: Self {
    .init(kind: .json)
  }

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
  /// The content type corresponding to this instance.
  var contentType: UTType {
    switch kind {
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

extension AttachableEncodingFormat: Equatable {}
extension AttachableEncodingFormat.Kind: Equatable {}
#endif
