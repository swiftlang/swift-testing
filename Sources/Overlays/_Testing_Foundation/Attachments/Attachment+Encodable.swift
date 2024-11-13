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
private import Foundation

/// A type that acts as an attachable container for a value that conforms to
/// [`Encodable`](https://developer.apple.com/documentation/swift/encodable).
///
/// You do not generally interact with this type directly. Instead, use
/// ``Testing/Attachment/init(encoding:named:sourceLocation:)`` to create
/// attachments from encodable values.
@_spi(Experimental)
public struct _EncodableContainer<AttachableValue>: AttachableContainer, Copyable where AttachableValue: Encodable {
  public var attachableValue: AttachableValue

  public func withUnsafeBufferPointer<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    let format = try EncodingFormat(for: attachment)

    let data: Data
    switch format {
    case let .propertyListFormat(propertyListFormat):
      let plistEncoder = PropertyListEncoder()
      plistEncoder.outputFormat = propertyListFormat
      data = try plistEncoder.encode(attachableValue)
    case .default:
      // The default format is JSON.
      fallthrough
    case .json:
      // We cannot use our own JSON encoding wrapper here because that would
      // require it be exported with (at least) package visibility which would
      // create a visible external dependency on Foundation in the main testing
      // library target.
      data = try JSONEncoder().encode(attachableValue)
    }

    return try data.withUnsafeBytes(body)
  }
}

extension _EncodableContainer: Sendable where AttachableValue: Sendable {}

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
  /// | `".xml"` | XML property list | [`PropertyListEncoder`](https://developer.apple.com/documentation/foundation/propertylistencoder) |
  /// | `".plist"` | Binary property list | [`PropertyListEncoder`](https://developer.apple.com/documentation/foundation/propertylistencoder) |
  /// | None, `".json"` | JSON | [`JSONEncoder`](https://developer.apple.com/documentation/foundation/jsonencoder) |
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
  ///   that conforms to [`UTType.propertyList`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/propertylist)
  ///   or to [`UTType.json`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/json).
  public init<T>(
    encoding encodableValue: T,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) where T: Encodable, AttachableValue == _EncodableContainer<T> {
    self.init(_EncodableContainer(attachableValue: encodableValue), named: preferredName, sourceLocation: sourceLocation)
  }
}
#endif
