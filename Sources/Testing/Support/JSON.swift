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
private import Foundation
#endif

enum JSON {
  /// Whether or not pretty-printed JSON is enabled for this process.
  ///
  /// This is a debugging tool that can be used by developers working on the
  /// testing library to improve the readability of JSON output.
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
  static func withEncoding<R>(of value: some Encodable, userInfo: [CodingUserInfoKey: any Sendable] = [:], _ body: (borrowing RawSpan) throws -> R) throws -> R {
#if canImport(Foundation)
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
    // WORKAROUND for older SDK on swift-ci (rdar://169480914)
    return try data.withUnsafeBytes { data in
      try body(data.bytes)
    }
#else
    throw SystemError(description: "JSON encoding requires Foundation which is not available in this environment.")
#endif
  }

  /// Post-process encoded JSON and write it to a file.
  ///
  /// - Parameters:
  ///   - json: The JSON to write.
  ///   - body: A function to call. A copy of `json` is passed to it with any
  ///     newlines removed.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  static func asJSONLine<R>(_ json: borrowing RawSpan, _ body: (borrowing RawSpan) throws -> R) rethrows -> R {
    let containsASCIINewline = json.withUnsafeBytes { json in
      json.contains(where: \.isASCIINewline)
    }
    if _slowPath(containsASCIINewline) {
      // Remove the newline characters to conform to JSON lines specification.
      // This is not actually expected to happen in practice with Foundation's
      // JSON encoder.
      var json = Array(json)
      json.removeAll(where: \.isASCIINewline)
      return try body(json.span.bytes)
    } else {
      // No newlines found, no need to copy the buffer.
      return try body(json)
    }
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
  static func decode<T>(_ type: T.Type, from jsonRepresentation: borrowing RawSpan) throws -> T where T: Decodable {
#if canImport(Foundation)
    try withExtendedLifetime(jsonRepresentation) {
      try jsonRepresentation.withUnsafeBytes { jsonRepresentation in
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
    }
#else
    throw SystemError(description: "JSON decoding requires Foundation which is not available in this environment.")
#endif
  }
}
