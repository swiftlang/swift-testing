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
@_spi(Experimental) public import Testing
public import Foundation

/// A type that acts as an attachable container for a value that conforms to
/// [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding).
///
/// You do not generally interact with this type directly. Instead, use
/// ``Testing/Attachment/init(encoding:named:sourceLocation:)`` to create
/// attachments from encodable values.
@_spi(Experimental)
public struct _NSSecureCodingContainer<AttachableValue>: AttachableContainer, Copyable where AttachableValue: NSSecureCoding {
  public var attachableValue: AttachableValue

  public func withUnsafeBufferPointer<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    let format = try EncodingFormat(for: attachment)

    var data = try NSKeyedArchiver.archivedData(withRootObject: attachableValue, requiringSecureCoding: true)
    switch format {
    case .default:
      // The default format is just what NSKeyedArchiver produces.
      break
    case let .propertyListFormat(propertyListFormat):
      // BUG: Foundation does not offer a variant of
      // NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding:)
      // that is Swift-safe (throws errors instead of exceptions) and lets the
      // caller specify the output format. Work around this issue by decoding
      // the archive re-encoding it manually.
      if propertyListFormat != .binary {
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        data = try PropertyListSerialization.data(fromPropertyList: plist, format: propertyListFormat, options: 0)
      }
    case .json:
      throw CocoaError(.propertyListWriteInvalid, userInfo: [NSLocalizedDescriptionKey: "An instance of \(type(of: self)) cannot be encoded as JSON. Specify a property list format instead."])
    }

    return try data.withUnsafeBytes(body)
  }
}

extension _NSSecureCodingContainer: Sendable where AttachableValue: Sendable {}

extension Attachment {
  /// Initialize an instance of this type that encloses the given value and that
  /// uses either [`PropertyListEncoder`](https://developer.apple.com/documentation/foundation/propertylistencoder)
  /// or [`JSONEncoder`](https://developer.apple.com/documentation/foundation/jsonencoder)
  /// to serialize it.
  ///
  /// - Parameters:
  ///   - encodableValue: The value that will be attached to the output of the
  ///     test run.
  ///   - preferredName: The preferred name of the attachment when writing it to
  ///     a test report or to disk. If `nil`, the testing library attempts to
  ///     derive a reasonable filename for the attached value.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// Use this initializer to create an attachment containing an instance of a
  /// type that conforms to [`Encodable`](https://developer.apple.com/documentation/swift/encodable).
  /// The encoding used depends on the path extension specified by the value of
  /// `preferredName`:
  ///
  /// | Extension | Encoding Used | Encoder Used |
  /// |-|-|-|
  /// | `".xml"` | XML property list | [`NSKeyedArchiver`](https://developer.apple.com/documentation/foundation/nskeyedarchiver) |
  /// | None, `".plist"` | Binary property list | [`NSKeyedArchiver`](https://developer.apple.com/documentation/foundation/nskeyedarchiver) |
  ///
  /// OpenStep-style property lists are not supported. If a value conforms to
  /// _both_ [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
  /// _and_ [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding),
  /// it is encoded using its conformance to [`Encodable`](https://developer.apple.com/documentation/swift/encodable).
  /// To force encoding a value using its conformance to [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding),
  /// cast it to `any NSSecureCoding` before initializing the attachment.
  ///
  /// - Note: On Apple platforms, if the attachment's preferred name includes
  ///   some other path extension, that path extension must represent a type
  ///   that conforms to [`UTType.propertyList`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/propertylist).
  @_disfavoredOverload
  public init<T>(
    encoding encodableValue: T,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) where T: NSSecureCoding, AttachableValue == _NSSecureCodingContainer<T> {
    self.init(_NSSecureCodingContainer(attachableValue: encodableValue), named: preferredName, sourceLocation: sourceLocation)
  }
}
#endif
