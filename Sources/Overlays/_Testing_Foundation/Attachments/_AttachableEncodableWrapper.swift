//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation)
public import Testing
private import Foundation

/// A wrapper type representing values that can be attached using their
/// conformances to the `Encodable` protocol.
///
/// You do not need to use this type directly. Instead, initialize an instance
/// of ``Attachment`` using the encodable value.
@_spi(Experimental)
public struct _AttachableEncodableWrapper<T> where T: Encodable {
  /// The underlying encodable value.
  private var _encodableValue: T

  /// The format to use when encoding ``value``.
  private var _encodingFormat: EncodingFormat

  /// Initialize an instance of this type representing a given encodable value.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - encodingFormat: The encoding format to use.
  init(encoding encodableValue: T, as encodingFormat: EncodingFormat) {
    _encodableValue = encodableValue
    _encodingFormat = encodingFormat
  }
}

extension _AttachableEncodableWrapper: Sendable where T: Sendable {}

// MARK: -

extension _AttachableEncodableWrapper: AttachableWrapper {
  public var wrappedValue: T {
    _encodableValue
  }

  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    let data: Data
    switch _encodingFormat {
    case let .propertyListFormat(propertyListFormat):
      let plistEncoder = PropertyListEncoder()
      plistEncoder.outputFormat = propertyListFormat
      data = try plistEncoder.encode(_encodableValue)
    case .json:
      // We cannot use our own JSON encoding wrapper here because that would
      // require it be exported with (at least) package visibility which would
      // create a visible external dependency on Foundation in the main testing
      // library target.
      data = try JSONEncoder().encode(_encodableValue)
    }

    return try data.withUnsafeBytes(body)
  }

  public borrowing func preferredName(for attachment: borrowing Attachment<Self>, basedOn suggestedName: String) -> String {
    let pathExtension = (suggestedName as NSString).pathExtension
    guard pathExtension.isEmpty else {
      return suggestedName
    }

    // TODO: tack on good extension
    return suggestedName
  }
}
#endif
