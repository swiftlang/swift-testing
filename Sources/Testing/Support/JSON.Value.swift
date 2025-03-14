//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension JSON {
  /// An enumeration representing the different kinds of value that can be
  /// encoded directly as JSON.
  enum Value: Sendable {
    /// The `null` constant (`nil` in Swift.)
    case null

    /// A boolean value.
    case bool(Bool)

    /// A signed integer value.
    case int64(Int64)

    /// An unsigned integer value.
    case uint64(UInt64)

    /// A floating point value.
    case double(Double)

    /// A string.
    case string(String)

    /// An array of values.
    case array([JSON.Value])

    /// An object (a dictionary in Swift.)
    case object([String: JSON.Value])
  }
}

extension JSON.Value {
  /// Call a function and pass it the JSON representation of a JSON keyword.
  ///
  /// - Parameters:
  ///   - value: A string representing the keyword. `StaticString` is used so
  ///     that the bytes representing the keyword can be acquired cheaply.
  ///   - body: The function to invoke. A buffer containing the JSON
  ///     representation of this keyword is passed.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  private static func _withUnsafeBytesForKeyword<R>(_ value: StaticString, _ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    // NOTE: StaticString.withUTF8Buffer does not rethrow.
    try withExtendedLifetime(value) {
      let buffer = UnsafeBufferPointer(start: value.utf8Start, count: value.utf8CodeUnitCount)
      return try body(.init(buffer))
    }
  }

  /// Call a function and pass it the JSON representation of a numeric value.
  ///
  /// - Parameters:
  ///   - value: A numeric value.
  ///   - body: The function to invoke. A buffer containing the JSON
  ///     representation of `value` is passed.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  private static func _withUnsafeBytesForNumericValue<V, R>(_ value: V, _ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R where V: Numeric {
    var string = String(describing: value)
    return try string.withUTF8 { utf8 in
      try body(.init(utf8))
    }
  }

  /// Call a function and pass it the JSON representation of a string.
  ///
  /// - Parameters:
  ///   - value: A string.
  ///   - body: The function to invoke. A buffer containing the JSON
  ///     representation of `value` is passed.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  private static func _withUnsafeBytesForString<R>(_ value: String, _ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    var result = [UInt8]()

    do {
      result.append(UInt8(ascii: #"""#))
      defer {
        result.append(UInt8(ascii: #"""#))
      }

      let scalars = value.unicodeScalars
      result.reserveCapacity(scalars.underestimatedCount + 2)

      for scalar in scalars {
        switch scalar {
        case Unicode.Scalar(0x0000) ..< Unicode.Scalar(0x0020):
          let hexValue = String(scalar.value, radix: 16)
          let leadingZeroes = repeatElement(UInt8(ascii: "0"), count: 4 - hexValue.count)
          result += leadingZeroes
          result += hexValue.utf8
        case #"""#, #"\"#:
          result += #"\\#(scalar)"#.utf8
        default:
          result += scalar.utf8
        }
      }
    }

    return try result.withUnsafeBytes(body)
  }

  /// Call a function and pass it the JSON representation of an array.
  ///
  /// - Parameters:
  ///   - value: An array of JSON values.
  ///   - body: The function to invoke. A buffer containing the JSON
  ///     representation of `value` is passed.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  private static func _withUnsafeBytesForArray<R>(_ value: [JSON.Value], _ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    var result = [UInt8]()

    do {
      result.append(UInt8(ascii: "["))
      defer {
        result.append(UInt8(ascii: "]"))
      }

      result += value.lazy.map { element in
        element.withUnsafeBytes { bytes in
          Array(bytes)
        }
      }.joined(separator: CollectionOfOne(UInt8(ascii: ",")))
    }

    return try result.withUnsafeBytes(body)
  }

  /// Call a function and pass it the JSON representation of an object (a
  /// dictionary in Swift).
  ///
  /// - Parameters:
  ///   - value: A JSON object.
  ///   - body: The function to invoke. A buffer containing the JSON
  ///     representation of `value` is passed.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  private static func _withUnsafeBytesForObject<R>(_ value: [String: JSON.Value], _ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    var result = [UInt8]()

    do {
      result.append(UInt8(ascii: "{"))
      defer {
        result.append(UInt8(ascii: "}"))
      }

      result += value.sorted { lhs, rhs in
        lhs.key < rhs.key
      }.map { key, value in
        key.makeJSONValue().withUnsafeBytes { serializedKey in
          value.withUnsafeBytes { serializedValue in
            var result = Array(serializedKey)
            result.append(UInt8(ascii: ":"))
            result += serializedValue
            return result
          }
        }
      }.joined(separator: CollectionOfOne(UInt8(ascii: ",")))
    }

    return try result.withUnsafeBytes(body)
  }

  /// Call a function and pass it the JSON representation of this JSON value.
  ///
  /// - Parameters:
  ///   - body: The function to invoke. A buffer containing the JSON
  ///     representation of this value is passed.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    switch self {
    case .null:
      return try Self._withUnsafeBytesForKeyword("null", body)
    case let .bool(value):
      return try Self._withUnsafeBytesForKeyword(value ? "true" : "false", body)
    case let .int64(value):
      return try Self._withUnsafeBytesForNumericValue(value, body)
    case let .uint64(value):
      return try Self._withUnsafeBytesForNumericValue(value, body)
    case let .double(value):
      return try Self._withUnsafeBytesForNumericValue(value, body)
    case let .string(value):
      return try Self._withUnsafeBytesForString(value, body)
    case let .array(value):
      return try Self._withUnsafeBytesForArray(value, body)
    case let .object(value):
      return try Self._withUnsafeBytesForObject(value, body)
    }
  }
}
