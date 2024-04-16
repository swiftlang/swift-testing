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
  static func withEncoding<R>(of value: some Encodable, userInfo: [CodingUserInfoKey: Any] = [:], _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
#if canImport(Foundation)
    let encoder = JSONEncoder()

    // Keys must be sorted to ensure deterministic matching of encoded data.
    encoder.outputFormatting.insert(.sortedKeys)

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
  ///   - jsonRepresentation: The JSON encoding of the value to decode.
  ///
  /// - Returns: An instance of `T` decoded from `jsonRepresentation`.
  ///
  /// - Throws: Whatever is thrown by the decoding process.
  static func decode<T>(_ _: T.Type, from jsonRepresentation: UnsafeRawBufferPointer) throws -> T where T: Decodable {
#if canImport(Foundation)
    try withExtendedLifetime(jsonRepresentation) {
      let data = Data(
        bytesNoCopy: .init(mutating: jsonRepresentation.baseAddress!),
        count: jsonRepresentation.count,
        deallocator: .none
      )
      return try JSONDecoder().decode(T.self, from: data)
    }
#else
    throw SystemError(description: "JSON decoding requires Foundation which is not available in this environment.")
#endif
  }
}
