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
private import Foundation
#endif

enum JSON {
  /// Encode a value as JSON.
  ///
  /// - Parameters:
  ///   - value: The value to encode.
  ///   - userInfo: Any user info to pass into the encoder during encoding.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body` or by the encoding process.
  static func withEncoding<J, E, R>(of value: J, _ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R where J: JSON.Serializable {
    try value.makeJSONValue().withUnsafeBytes { json throws(E) in
      try body(json)
    }
  }
}

// MARK: - Foundation-based JSON support

extension JSON {
  /// Whether or not pretty-printed JSON is enabled for this process.
  ///
  /// This is a debugging tool that can be used by developers working on the
  /// testing library to improve the readability of JSON output.
  ///
  /// This property is only used by the Foundation-based overload of
  /// `withEncoding()`. It is ignored when using ``JSON/Serializable``.
  private static let _prettyPrintingEnabled = Environment.flag(named: "SWT_PRETTY_PRINT_JSON") == true

  /// Encode a value as JSON.
  ///
  /// - Parameters:
  ///   - value: The value to encode.
  ///   - userInfo: Any user info to pass into the encoder during encoding.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body` or by the encoding process.
  @_disfavoredOverload
  static func withEncoding<R>(of value: some Encodable, userInfo: [CodingUserInfoKey: any Sendable] = [:], _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
#if !SWT_NO_FOUNDATION && canImport(Foundation)
    let encoder = JSONEncoder()

    // Keys must be sorted to ensure deterministic matching of encoded data.
    encoder.outputFormatting.insert(.sortedKeys)
    if _prettyPrintingEnabled {
      encoder.outputFormatting.insert(.prettyPrinted)
      encoder.outputFormatting.insert(.withoutEscapingSlashes)
    }

    // Set user info keys that clients want to use during encoding.
    encoder.userInfo.merge(userInfo, uniquingKeysWith: { _, rhs in rhs})

    let data = try encoder.encode(value)
    return try data.withUnsafeBytes(body)
#else
    throw SystemError(description: "JSON encoding requires Foundation which is not available in this environment.")
#endif
  }

  /// Decode a value from JSON data.
  ///
  /// - Parameters:
  ///   - type: The type of value to decode.
  ///   - jsonRepresentation: The JSON encoding of the value to decode.
  ///
  /// - Returns: An instance of `T` decoded from `jsonRepresentation`.
  ///
  /// - Throws: Whatever is thrown by the decoding process.
  static func decode<T>(_ type: T.Type, from jsonRepresentation: UnsafeRawBufferPointer) throws -> T where T: Decodable {
#if !SWT_NO_FOUNDATION && canImport(Foundation)
    try withExtendedLifetime(jsonRepresentation) {
      let byteCount = jsonRepresentation.count
      let data = if byteCount > 0 {
        Data(
          bytesNoCopy: .init(mutating: jsonRepresentation.baseAddress!),
          count: byteCount,
          deallocator: .none
        )
      } else {
        Data()
      }
      return try JSONDecoder().decode(type, from: data)
    }
#else
    throw SystemError(description: "JSON decoding requires Foundation which is not available in this environment.")
#endif
  }
}
