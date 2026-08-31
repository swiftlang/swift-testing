//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
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
public struct _AttachableEncodableWrapper<T> where T: Encodable {
  /// The underlying encodable value.
  private var _encodableValue: T

  /// The encoding format used when encoding the value.
  private var _encodingFormat: AttachableEncodingFormat?

  /// A function that encodes `_encodableValue` and passes its encoded form to
  /// another function, `body`.
  ///
  /// This function provides the implementation of ``withBytes(for:_:)``. We
  /// must pass `encodableValue` as an existential box instead of an instance of
  /// `T` because otherwise `_encode` captures a reference to the generic type
  /// `T` which is not guaranteed to conform to `SendableMetatype`.
  private var _encode: @Sendable (_ encodableValue: any Encodable, _ body: (UnsafeRawBufferPointer) throws -> Void) throws -> Void

#if canImport(Combine)
  /// Initialize an instance of this type representing a given encodable value
  /// and encoding it using the given encoder.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - encoder: The encoder to use.
  init<E>(encoding encodableValue: T, using encoder: E) where E: TopLevelEncoder & Sendable, E.Output: ContiguousBytes {
    _encodableValue = encodableValue
    if let plistEncoder = encoder as? PropertyListEncoder {
      _encodingFormat = .propertyListFormat(plistEncoder.outputFormat)
    } else if encoder is JSONEncoder {
      _encodingFormat = .json
    }
    _encode = { encodableValue, body in
      let buffer = try encoder.encode(encodableValue)
      try buffer.withUnsafeBytes(body)
    }
  }
#else
  init<E>(encoding encodableValue: T, using encoder: E) where E: PropertyListEncoder & Sendable {
    _encodableValue = encodableValue
    _encodingFormat = .propertyListFormat(encoder.outputFormat)
    _encode = { encodableValue, body in
      let buffer = try encoder.encode(encodableValue)
      try buffer.withUnsafeBytes(body)
    }
  }

  init<E>(encoding encodableValue: T, using encoder: E) where E: JSONEncoder & Sendable {
    _encodableValue = encodableValue
    _encodingFormat = .json
    _encode = { encodableValue, body in
      let buffer = try encoder.encode(encodableValue)
      try buffer.withUnsafeBytes(body)
    }
  }
#endif
}

extension _AttachableEncodableWrapper: Sendable where T: Sendable {}

// MARK: -

extension _AttachableEncodableWrapper: AttachableWrapper {
  public var wrappedValue: T {
    _encodableValue
  }

  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<_AttachableEncodableWrapper>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var result: R!
    try _encode(_encodableValue) { buffer in
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
