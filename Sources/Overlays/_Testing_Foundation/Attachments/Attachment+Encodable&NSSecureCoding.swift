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
public import Testing
public import Foundation
#if canImport(Combine)
public import Combine
#endif

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

@_spi(Experimental)
extension Attachment {
#if !SWT_NO_CODABLE
  /// Derive an instance of `EncodingFormat` from the arguments to one of the
  /// initializers in this file.
  ///
  /// - Parameters:
  ///   - encodingFormat: An explicit instance of `EncodingFormat`, if passed by
  ///     the initializer's caller.
  ///   - preferredName: The preferred name of the attachment.
  ///   - default: The value to return if neither `encodingFormat` nor
  ///     `preferredName` produces a useful value.
  ///
  /// - Throws: If `preferredName` implies a format that `EncodingFormat` can't
  ///   represent (e.g. "MP3 track" or "GIF image") or if it represents the
  ///   OpenStep property list format.
  ///
  /// - Returns: An instance of `EncodingFormat` to use when later encoding an
  ///   attachment.
  private static func _encodingFormat(
    _ encodingFormat: EncodingFormat?,
    forPreferredName preferredName: String?,
    `default`: @autoclosure() -> EncodingFormat
  ) throws -> EncodingFormat {
    if let encodingFormat {
      // The caller explicitly supplied an encoding format.
      if case .propertyListFormat(.openStep) = encodingFormat {
        throw CocoaError(.propertyListWriteInvalid, userInfo: [NSLocalizedDescriptionKey: "The OpenStep property list format is not supported."])
      }
      return encodingFormat
    }

    if let preferredName,
       case let ext = (preferredName as NSString).pathExtension,
       !ext.isEmpty {
      // Check if the path extension is one we directly associate with a
      // particular encoding format.
      if ext.caseInsensitiveCompare("plist") == .orderedSame {
        return .propertyListFormat(.binary)
      } else if ext.caseInsensitiveCompare("xml") == .orderedSame {
        return .propertyListFormat(.xml)
      } else if ext.caseInsensitiveCompare("json") == .orderedSame {
        return .json
      }

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
      // There is some other path extension. Check with Launch Services for a
      // Uniform Type Identifier that conforms to one we support.
      if let contentType = UTType(filenameExtension: ext) {
        if contentType.conforms(to: .binaryPropertyList) {
          return .propertyListFormat(.binary)
        } else if contentType.conforms(to: .xmlPropertyList) {
          return .propertyListFormat(.xml)
        } else if contentType.conforms(to: .json) {
          return .json
        }
      }
#endif

      // The path extension is unknown to us.
      throw CocoaError(.propertyListWriteInvalid, userInfo: [NSLocalizedDescriptionKey: "The path extension '.\(ext)' cannot be used to attach an instance of \(type(of: self)) to a test."])
    }

    return `default`()
  }

  /// Initialize an instance of this type representing a value that conforms to
  /// the [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
  /// protocol.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - encodingFormat: The encoding format to use to encode `encodableValue`.
  ///   - preferredName: The preferred name of the attachment when writing it to
  ///     a test report or to disk.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// - Throws: If an appropriate encoder could not be found given the
  ///   `encodingFormat` and `preferredName` arguments.
  ///
  /// Use this initializer to create an instance of ``Attachment`` from a value
  /// that conforms to the [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
  /// protocol:
  ///
  /// ```swift
  /// let menu = FoodTruck.currentMenu
  /// let attachment = try Attachment(encoding: menu, as: .json)
  /// Attachment.record(attachment)
  /// ```
  ///
  /// The encoding that the testing library uses depends on the `encodingFormat`
  /// argument. If the value of that argument is `nil`, the testing library
  /// derives the format from the path extension you specify in `preferredName`.
  ///
  /// | Extension | Encoding Used | Encoder Used |
  /// |-|-|-|
  /// | `".xml"` | XML property list | [`PropertyListEncoder`](https://developer.apple.com/documentation/foundation/propertylistencoder) |
  /// | `".plist"` | Binary property list | [`PropertyListEncoder`](https://developer.apple.com/documentation/foundation/propertylistencoder) |
  /// | None, `".json"` | JSON | [`JSONEncoder`](https://developer.apple.com/documentation/foundation/jsonencoder) |
  ///
  /// - Important: OpenStep-style property lists are not supported.
  ///
  /// If the values of both the `encodingFormat` and `preferredName` arguments
  /// are `nil`, the testing library encodes `encodableValue` as JSON.
  public init<T>(
    encoding encodableValue: T,
    as encodingFormat: EncodingFormat? = nil,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where AttachableValue == _AttachableEncodableWrapper<T, Void>, T: Encodable {
    let encodingFormat = try Self._encodingFormat(encodingFormat, forPreferredName: preferredName, default: .json)
    let wrapper = _AttachableEncodableWrapper(encoding: encodableValue, as: encodingFormat)
    self.init(wrapper, named: preferredName, sourceLocation: sourceLocation)
  }

#if canImport(Combine)
  /// Initialize an instance of this type representing a value that conforms to
  /// the [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
  /// protocol.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - encoder: The encoder to use to encode `encodableValue`.
  ///   - preferredName: The preferred name of the attachment when writing it to
  ///     a test report or to disk.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// - Throws: If `encoder` cannot be used to encode `encodableValue`.
  ///
  /// Use this initializer to create an instance of ``Attachment`` from a value
  /// that conforms to the [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
  /// protocol:
  ///
  /// ```swift
  /// let menu = FoodTruck.currentMenu
  /// let encoder = JSONEncoder()
  /// let attachment = try Attachment(encoding: menu, using: encoder)
  /// Attachment.record(attachment)
  /// ```
  public init<T, E>(
    encoding encodableValue: T,
    using encoder: E,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where AttachableValue == _AttachableEncodableWrapper<T, E>, T: Encodable, E: TopLevelEncoder, E.Output: ContiguousBytes {
    let wrapper = _AttachableEncodableWrapper(encoding: encodableValue, using: encoder)
    self.init(wrapper, named: preferredName, sourceLocation: sourceLocation)
  }
#else
  public init<T, E>(
    encoding encodableValue: T,
    using encoder: E,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where AttachableValue == _AttachableEncodableWrapper<T, E>, T: Encodable, E: PropertyListEncoder {
    let wrapper = _AttachableEncodableWrapper(encoding: encodableValue, using: encoder)
    self.init(wrapper, named: preferredName, sourceLocation: sourceLocation)
  }

  public init<T, E>(
    encoding encodableValue: T,
    using encoder: E,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where AttachableValue == _AttachableEncodableWrapper<T, E>, T: Encodable, E: JSONEncoder {
    let wrapper = _AttachableEncodableWrapper(encoding: encodableValue, using: encoder)
    self.init(wrapper, named: preferredName, sourceLocation: sourceLocation)
  }
#endif
#endif

  /// Initialize an instance of this type representing a value that conforms to
  /// the [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding)
  /// protocol.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - propertyListFormat: The property list format to use to encode
  ///     `encodableValue`.
  ///   - preferredName: The preferred name of the attachment when writing it to
  ///     a test report or to disk.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// - Throws: If an appropriate encoder could not be found given the
  ///   `propertyListFormat` and `preferredName` arguments.
  ///
  /// Use this initializer to create an instance of ``Attachment`` from a value
  /// that conforms to the [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding)
  /// protocol:
  ///
  /// ```swift
  /// let menu = FoodTruck.currentMenu
  /// let attachment = try Attachment(encoding: menu, as: .xml)
  /// Attachment.record(attachment)
  /// ```
  ///
  /// The encoding that the testing library uses depends on the
  /// `propertyListFormat` argument. If the value of that argument is `nil`, the
  /// testing library derives the format from the path extension you specify in
  /// `preferredName`.
  ///
  /// | Extension | Encoding Used | Encoder Used |
  /// |-|-|-|
  /// | `".xml"` | XML property list | [`NSKeyedArchiver`](https://developer.apple.com/documentation/foundation/nskeyedarchiver) |
  /// | None, `".plist"` | Binary property list | [`NSKeyedArchiver`](https://developer.apple.com/documentation/foundation/nskeyedarchiver) |
  ///
  /// - Important: OpenStep-style property lists are not supported.
  ///
  /// If the values of both the `propertyListFormat` and `preferredName`
  /// arguments are `nil`, the testing library encodes `encodableValue` as a
  /// binary property list.
  public init<T>(
    encoding encodableValue: T,
    as propertyListFormat: PropertyListSerialization.PropertyListFormat? = nil,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where AttachableValue == _AttachableEncodableWrapper<T, NSKeyedArchiver>, T: NSSecureCoding {
    // Convert the property list format to an instance of EncodingFormat. This
    // is a bit roundabout, but it allows us to reuse logic in EncodingFormat to
    // translate to/from path extensions and UTTypes.
    let encodingFormat = try Self._encodingFormat(
      propertyListFormat.map { .propertyListFormat($0) },
      forPreferredName: preferredName,
      default: .propertyListFormat(.binary)
    )
    switch encodingFormat {
    case let .propertyListFormat(propertyListFormat):
      // This format is supported. (The OpenStep case was handled above).
      let wrapper = _AttachableEncodableWrapper(encoding: encodableValue, as: propertyListFormat)
      self.init(wrapper, named: preferredName, sourceLocation: sourceLocation)
    case .json:
      throw CocoaError(.propertyListWriteInvalid, userInfo: [NSLocalizedDescriptionKey: "An instance of \(T.self) cannot be encoded as JSON. Specify a property list format instead."])
    }
  }
}
#endif
