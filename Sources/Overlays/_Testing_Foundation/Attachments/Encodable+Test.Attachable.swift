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

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
private import UniformTypeIdentifiers
#endif

// Implement the protocol requirements generically for any encodable value by
// encoding to JSON. This lets developers provide trivial conformance to the
// protocol for types that already support Codable.
@_spi(Experimental)
extension Encodable where Self: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    let format = try EncodingFormat(for: attachment)

    let data: Data
    switch format {
    case let .propertyListFormat(propertyListFormat):
      let plistEncoder = PropertyListEncoder()
      plistEncoder.outputFormat = propertyListFormat
      data = try plistEncoder.encode(self)
    case .default:
      // The default format is JSON.
      fallthrough
    case .json:
      // We cannot use our own JSON encoding wrapper here because that would
      // require it be exported with (at least) package visibility which would
      // create a visible external dependency on Foundation in the main testing
      // library target.
      data = try JSONEncoder().encode(self)
    }

    return try data.withUnsafeBytes(body)
  }
}
#endif
