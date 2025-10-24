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
internal import Foundation

/// The common implementation of ``withUnsafeBytes(for:_:)`` and
/// ``withBytes(for:_:)`` for types conforming to `Encodable`.
///
/// - Parameters:
///   - attachableValue: The value to encode.
///   - attachment: The attachment that is requesting data (that is, the
///     attachment containing `attachableValue`.)
///
/// - Returns: An encoded representation `attachableValue`.
///
/// - Throws: Any error that prevented creation of the data.
func _data<E>(encoding attachableValue: borrowing E, for attachment: borrowing Attachment<E>) throws -> Data where E: Attachable & Encodable {
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

  return data
}

// Implement the protocol requirements generically for any encodable value by
// encoding to JSON. This lets developers provide trivial conformance to the
// protocol for types that already support Codable.

/// @Metadata {
///   @Available(Swift, introduced: 6.2)
///   @Available(Xcode, introduced: 26.0)
/// }
extension Attachable where Self: Encodable {
  /// Encode this value into a buffer using either [`PropertyListEncoder`](https://developer.apple.com/documentation/foundation/propertylistencoder)
  /// or [`JSONEncoder`](https://developer.apple.com/documentation/foundation/jsonencoder),
  /// then call a function and pass that buffer to it.
  ///
  /// - Parameters:
  ///   - attachment: The attachment that is requesting a buffer (that is, the
  ///     attachment containing this instance.)
  ///   - body: A function to call. A temporary buffer containing a data
  ///     representation of this instance is passed to it.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`, or any error that prevented the
  ///   creation of the buffer.
  ///
  /// The testing library uses this function when writing an attachment to a
  /// test report or to a file on disk. The encoding used depends on the path
  /// extension specified by the value of `attachment`'s ``Testing/Attachment/preferredName``
  /// property:
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
  /// the default implementation of this function uses the value's conformance
  /// to `Encodable`.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.2)
  ///   @Available(Xcode, introduced: 26.0)
  /// }
  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try default_withUnsafeBytes(for: attachment, body)
  }

  /// Encode this value into a span using either [`PropertyListEncoder`](https://developer.apple.com/documentation/foundation/propertylistencoder)
  /// or [`JSONEncoder`](https://developer.apple.com/documentation/foundation/jsonencoder),
  /// then call a function and pass that span to it.
  ///
  /// - Parameters:
  ///   - attachment: The attachment that is requesting a span (that is, the
  ///     attachment containing this instance.)
  ///   - body: A function to call. A temporary span containing a data
  ///     representation of this instance is passed to it.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`, or any error that prevented the
  ///   creation of the span.
  ///
  /// The testing library uses this function when writing an attachment to a
  /// test report or to a file on disk. The encoding used depends on the path
  /// extension specified by the value of `attachment`'s ``Testing/Attachment/preferredName``
  /// property:
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
  /// the default implementation of this function uses the value's conformance
  /// to `Encodable`.
  public borrowing func withBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (borrowing RawSpan) throws -> R) throws -> R {
    try body(_data(encoding: self, for: attachment).bytes)
  }
}
#endif
