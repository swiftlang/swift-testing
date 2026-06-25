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
import Foundation
#if canImport(Combine)
import Combine
#endif
#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
private import UniformTypeIdentifiers
#endif

/// A wrapper type representing values that can be attached using their
/// conformances to the `Encodable` protocol.
///
/// You do not need to use this type directly. Instead, initialize an instance
/// of ``Attachment`` using the encodable value.
@_spi(Experimental)
public struct _AttachableEncodableWrapper<T, E> where T: Encodable {
  /// The underlying encodable value.
  private var _encodableValue: T

  /// The encoding format used by
  private var _encodingFormat: EncodingFormat?

  /// A function that encodes `_encodableValue` and passes its encoded form to
  /// another function, `body`.
  ///
  /// This function provides the implementation of ``withBytes(for:_:)``. It
  /// must be annotated `nonisolated(unsafe)` instead of `@Sendable` because it
  /// captures a reference to the generic type `T` which is not guaranteed to
  /// conform to `SendableMetatype`.
  private nonisolated(unsafe) var _encode: (borrowing T, _ body: (UnsafeRawBufferPointer) throws -> Void) throws -> Void

  /// Initialize an instance of this type representing a given encodable value
  /// and encoding it using the given encoding format.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - encodingFormat: The encoding format to use.
  init(encoding encodableValue: T, as encodingFormat: EncodingFormat) where E == Void {
    _encodableValue = encodableValue
    _encodingFormat = encodingFormat
    _encode = { encodableValue, body in
      let data: Data
      switch encodingFormat {
      case let .propertyListFormat(propertyListFormat):
        let plistEncoder = PropertyListEncoder()
        plistEncoder.outputFormat = propertyListFormat
        data = try plistEncoder.encode(encodableValue)
      case .json:
        // We cannot use our own JSON encoding wrapper here because that would
        // require it be exported with (at least) package visibility which would
        // create a visible external dependency on Foundation in the main testing
        // library target.
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
  init(encoding encodableValue: T, using encoder: E) where E: TopLevelEncoder, E.Output: ContiguousBytes {
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
#endif
}

extension _AttachableEncodableWrapper: Sendable where T: Sendable, E: Sendable {}

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
#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
    if let contentType = _encodingFormat?.contentType {
      return (suggestedName as NSString).appendingPathExtension(for: contentType)
    }
#else
    let pathExtension = (suggestedName as NSString).pathExtension
    guard pathExtension.isEmpty else {
      // The developer specified a path extension. This path extension may
      // reflect some file format that uses Encodable for serialization, so use
      // it verbatim.
      return suggestedName
    }
    if let encodingFormat = _encodingFormat {
      return (suggestedName as NSString).appendingPathExtension(encodingFormat.preferredPathExtension)
    }
#endif
    return suggestedName
  }
}
#endif
