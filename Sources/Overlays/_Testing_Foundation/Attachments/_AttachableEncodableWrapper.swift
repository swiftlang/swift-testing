//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation) && !SWT_NO_CODABLE
public import Testing
import Foundation
#if canImport(Combine)
import Combine
#endif

/// A wrapper type representing values that can be attached using their
/// conformances to the `Encodable` protocol.
///
/// You do not need to use this type directly. Instead, initialize an instance
/// of ``Attachment`` using the encodable value.
@_spi(Experimental)
public struct _AttachableEncodableWrapper<T, E> {
  /// The underlying encodable value.
  private var _encodableValue: T

  /// The encoding format used when encoding the value.
  private var _encodingFormat: EncodingFormat?

  /// A function that encodes `_encodableValue` and passes its encoded form to
  /// another function, `body`.
  ///
  /// This function provides the implementation of ``withBytes(for:_:)``. It
  /// must be annotated `nonisolated(unsafe)` instead of `@Sendable` because it
  /// captures a reference to the generic type `T` which is not guaranteed to
  /// conform to `SendableMetatype`.
  private nonisolated(unsafe) var _encode: (_ body: (UnsafeRawBufferPointer) throws -> Void) throws -> Void

  /// Initialize an instance of this type representing a given encodable value
  /// and encoding it using the given encoding format.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - encodingFormat: The encoding format to use.
  init(encoding encodableValue: T, as encodingFormat: EncodingFormat) where T: Encodable, E == Void {
    _encodableValue = encodableValue
    _encodingFormat = encodingFormat
    _encode = { body in
      let data: Data
      switch encodingFormat {
      case let .propertyListFormat(propertyListFormat):
        let plistEncoder = PropertyListEncoder()
        plistEncoder.outputFormat = propertyListFormat
        data = try plistEncoder.encode(encodableValue)
      case .json:
        // We cannot use our own JSON encoding wrapper here because that would
        // require it be exported with (at least) package visibility which would
        // create a visible external dependency on Foundation in the main
        // testing library target.
        data = try JSONEncoder().encode(encodableValue)
      }

      return try data.withUnsafeBytes(body)
    }
  }

#if canImport(Combine)
  /// Initialize an instance of this type representing a given encodable value
  /// and encoding it using the given encoder.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - encoder: The encoder to use.
  init(encoding encodableValue: T, using encoder: E) where T: Encodable, E: TopLevelEncoder, E.Output: ContiguousBytes {
    _encodableValue = encodableValue
    if let plistEncoder = encoder as? PropertyListEncoder {
      _encodingFormat = .propertyListFormat(plistEncoder.outputFormat)
    } else if encoder is JSONEncoder {
      _encodingFormat = .json
    }
    _encode = { body in
      let buffer = try encoder.encode(encodableValue)
      try buffer.withUnsafeBytes(body)
    }
  }
#else
  init(encoding encodableValue: T, using encoder: E) where T: Encodable, E: PropertyListEncoder {
    _encodableValue = encodableValue
    _encodingFormat = .propertyListFormat(encoder.outputFormat)
    _encode = { body in
      let buffer = try encoder.encode(encodableValue)
      try buffer.withUnsafeBytes(body)
    }
  }

  init(encoding encodableValue: T, using encoder: E) where T: Encodable, E: JSONEncoder {
    _encodableValue = encodableValue
    _encodingFormat = .json
    _encode = { body in
      let buffer = try encoder.encode(encodableValue)
      try buffer.withUnsafeBytes(body)
    }
  }
#endif

  /// Initialize an instance of this type representing a given encodable value
  /// and encoding it using the given encoding format.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - propertyListFormat: The property list format to use.
  init(encoding encodableValue: T, as propertyListFormat: PropertyListSerialization.PropertyListFormat) where T: NSSecureCoding, E: NSKeyedArchiver {
    _encodableValue = encodableValue
    _encodingFormat = .propertyListFormat(propertyListFormat)
    _encode = { body in
      var data = try E.archivedData(withRootObject: encodableValue, requiringSecureCoding: true)

      // BUG: Foundation does not offer a variant of
      // NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding:)
      // that is Swift-safe (throws errors instead of exceptions) and lets the
      // caller specify the output format. Work around this issue by decoding
      // the archive re-encoding it manually.
      if propertyListFormat != .binary {
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        data = try PropertyListSerialization.data(fromPropertyList: plist, format: propertyListFormat, options: 0)
      }

      return try data.withUnsafeBytes(body)
    }
  }
}

extension _AttachableEncodableWrapper: Sendable where T: Sendable, E: Sendable {}

// MARK: -

extension _AttachableEncodableWrapper: AttachableWrapper {
  public var wrappedValue: T {
    _encodableValue
  }

  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<_AttachableEncodableWrapper>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var result: R!
    try _encode { buffer in
      result = try body(buffer)
    }
    return result
  }

  public borrowing func preferredName(for attachment: borrowing Attachment<_AttachableEncodableWrapper>, basedOn suggestedName: String) -> String {
    guard let encodingFormat = _encodingFormat else {
      return suggestedName
    }
    return encodingFormat.preferredName(basedOn: suggestedName)
  }
}
#endif
