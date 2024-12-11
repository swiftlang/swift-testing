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
private import UniformTypeIdentifiers
#endif

/// An enumeration describing the encoding formats supported by default when
/// encoding a value that conforms to ``Testing/Attachable`` and either
/// [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
/// or [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding).
public struct EncodableAttachmentMetadata: Sendable {
  /// An enumeration describing the encoding formats supported by default when
  /// encoding a value that conforms to ``Testing/Attachable`` and either
  /// [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
  /// or [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding).
  public enum Format: Sendable {
    /// The encoding format to use by default.
    ///
    /// The specific format this case corresponds to depends on if we are encoding
    /// an `Encodable` value or an `NSSecureCoding` value.
    case `default`

    /// A property list format.
    ///
    /// - Parameters:
    ///   - format: The corresponding property list format.
    ///
    /// OpenStep-style property lists are not supported.
    case propertyListFormat(_ format: PropertyListSerialization.PropertyListFormat)

    /// The JSON format.
    case json
  }

  /// The format the attachable value should be encoded as.
  public var format: Format

  /// A type describing the various JSON encoding options to use if
  /// [`JSONEncoder`](https://developer.apple.com/documentation/foundation/jsonencoder)
  /// is used to encode the attachable value.
  public struct JSONEncodingOptions: Sendable {
    /// The output format to produce.
    public var outputFormatting: JSONEncoder.OutputFormatting

    /// The strategy to use in encoding dates.
    public var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy

    /// The strategy to use in encoding binary data.
    public var dataEncodingStrategy: JSONEncoder.DataEncodingStrategy

    /// The strategy to use in encoding non-conforming numbers.
    public var nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy

    /// The strategy to use for encoding keys.
    public var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy
  }

  /// JSON encoding options to use if [`JSONEncoder`](https://developer.apple.com/documentation/foundation/jsonencoder)
  /// is used to encode the attachable value.
  ///
  /// The default value of this property is `nil`, meaning that the default
  /// options are used when encoding an attachable value as JSON. If an
  /// attachable value is encoded in a format other than JSON, the value of this
  /// property is ignored.
  public var jsonEncodingOptions: JSONEncodingOptions?

  /// A user info dictionary to provide to the property list encoder or JSON
  /// encoder when encoding the attachable value.
  ///
  /// The value of this property is ignored when encoding an attachable value
  /// that conforms to [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding)
  /// but does not conform to [`Encodable`](https://developer.apple.com/documentation/swift/encodable).
  public var userInfo: [CodingUserInfoKey: any Sendable]

  public init(format: Format, jsonEncodingOptions: JSONEncodingOptions? = nil, userInfo: [CodingUserInfoKey: any Sendable] = [:]) {
    self.format = format
    self.jsonEncodingOptions = jsonEncodingOptions
    self.userInfo = userInfo
  }
}

// MARK: -

extension EncodableAttachmentMetadata.JSONEncodingOptions {
  public init(
    outputFormatting: JSONEncoder.OutputFormatting? = nil,
    dateEncodingStrategy: JSONEncoder.DateEncodingStrategy? = nil,
    dataEncodingStrategy: JSONEncoder.DataEncodingStrategy? = nil,
    nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy? = nil,
    keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy? = nil
  ) {
    self = .default
    self.outputFormatting = outputFormatting ?? self.outputFormatting
    self.dateEncodingStrategy = dateEncodingStrategy ?? self.dateEncodingStrategy
    self.dataEncodingStrategy = dataEncodingStrategy ?? self.dataEncodingStrategy
    self.nonConformingFloatEncodingStrategy = nonConformingFloatEncodingStrategy ?? self.nonConformingFloatEncodingStrategy
    self.keyEncodingStrategy = keyEncodingStrategy ?? self.keyEncodingStrategy
  }

  /// An instance of this type representing the default JSON encoding options
  /// used by [`JSONEncoder`](https://developer.apple.com/documentation/foundation/jsonencoder).
  public static let `default`: Self = {
    // Get the default values from a real JSONEncoder for max authenticity!
    let encoder = JSONEncoder()

    return Self(
      outputFormatting: encoder.outputFormatting,
      dateEncodingStrategy: encoder.dateEncodingStrategy,
      dataEncodingStrategy: encoder.dataEncodingStrategy,
      nonConformingFloatEncodingStrategy: encoder.nonConformingFloatEncodingStrategy,
      keyEncodingStrategy: encoder.keyEncodingStrategy
    )
  }()
}

// MARK: -

extension EncodableAttachmentMetadata.Format {
  /// Initialize an instance of this type representing the content type or media
  /// type of the specified attachment.
  ///
  /// - Parameters:
  ///   - attachment: The attachment that will be encoded.
  ///
  /// - Throws: If the attachment's content type or media type is unsupported.
  init<A>(for attachment: borrowing Attachment<A>) throws where A: Attachable, A.AttachmentMetadata == EncodableAttachmentMetadata? {
    if let metadata = attachment.metadata {
      self = metadata.format
      return
    }

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
