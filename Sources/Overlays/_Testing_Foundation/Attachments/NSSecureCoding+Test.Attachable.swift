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

// As with Encodable, implement the protocol requirements for
// NSSecureCoding-conformant classes by default. The implementation uses
// NSKeyedArchiver for encoding.
@_spi(Experimental)
extension NSSecureCoding where Self: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
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
