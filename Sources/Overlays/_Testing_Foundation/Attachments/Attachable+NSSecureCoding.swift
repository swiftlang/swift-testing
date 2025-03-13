//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_FOUNDATION && canImport(Foundation)
@_spi(Experimental) public import Testing
public import Foundation

// As with Encodable, implement the protocol requirements for
// NSSecureCoding-conformant classes by default. The implementation uses
// NSKeyedArchiver for encoding.
@_spi(Experimental)
extension Attachable where Self: NSSecureCoding {
  /// Encode this object using [`NSKeyedArchiver`](https://developer.apple.com/documentation/foundation/nskeyedarchiver)
  /// into a buffer, then call a function and pass that buffer to it.
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
  /// | `".xml"` | XML property list | [`NSKeyedArchiver`](https://developer.apple.com/documentation/foundation/nskeyedarchiver) |
  /// | None, `".plist"` | Binary property list | [`NSKeyedArchiver`](https://developer.apple.com/documentation/foundation/nskeyedarchiver) |
  ///
  /// OpenStep-style property lists are not supported. If a value conforms to
  /// _both_ [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
  /// _and_ [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding),
  /// the default implementation of this function uses the value's conformance
  /// to `Encodable`.
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    let format = try EncodingFormat(for: attachment)

    var data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
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
#endif
