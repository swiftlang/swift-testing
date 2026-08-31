//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if DEBUG && !SWT_NO_FILE_IO && canImport(Foundation)
private import Foundation
#endif

extension JSON {
  /// A type representing a number that can be encoded as JSON.
  enum Number: Sendable {
    /// The type this enumeration uses to represent signed integers.
    typealias SignedInteger = Int64 // could be Int128 on some platforms

    /// A signed integer.
    ///
    /// - Parameters:
    ///   - value: The represented integer value.
    case signedInteger(_ value: SignedInteger)

    /// The type this enumeration uses to represent unsigned integers.
    typealias UnsignedInteger = SignedInteger.Magnitude

    /// An unsigned integer.
    ///
    /// - Parameters:
    ///   - value: The represented integer value.
    case unsignedInteger(_ value: UnsignedInteger)

    /// The type this enumeration uses to represent floating-point numbers.
    typealias FloatingPoint = Double

    /// A floating-point number.
    ///
    /// - Parameters:
    ///   - value: The represented floating-point value.
    case floatingPoint(_ value: FloatingPoint)
  }

  /// A type representing any value that can be encoded as JSON.
  enum Value: Sendable {
    /// A string.
    ///
    /// - Parameters:
    ///   - string: The represented string value.
    ///
    /// JSON encodes strings as UTF-8.
    case string(_ string: String)

    /// A number.
    ///
    /// - Parameters:
    ///   - number: The represented numeric value.
    case number(_ number: JSON.Number)

    /// A JSON object (in Swift, a dictionary).
    ///
    /// - Parameters:
    ///   - object: The represented Swift dictionary or JSON object.
    case object(_ object: [String: JSON.Value])

    /// An array.
    ///
    /// - Parameters:
    ///   - array: The represented array.
    case array(_ array: [JSON.Value])

    /// A boolean value.
    ///
    /// - Parameters:
    ///   - bool: The represented boolean value.
    case bool(_ bool: Bool)

    /// The null value (in Swift, `nil`).
    ///
    /// The testing library typically omits `nil` values rather than encoding
    /// `nil`, but this case is included for completeness.
    case null
  }
}

extension JSON {
  /// A protocol describing a type that can be encoded as JSON.
  ///
  /// We use this protocol to support encoding JSON, and in particular the JSON
  /// event stream, without relying on `Codable` or `JSONEncoder`. Some targets,
  /// i.e. Embedded Swift, do not implement or support `Codable`.
  protocol Encodable {
    /// The type of error thrown from ``jsonValue(in:)``.
    associatedtype JSONEncodingError: Error = any Error

    /// Get a JSON value representing this value.
    ///
    /// - Parameters:
    ///   - context: Context for the encoding session.
    ///
    /// - Returns: An instance of ``JSON/Value`` representing this value.
    ///
    /// - Throws: Any error that prevents encoding this value as JSON.
    func jsonValue(in context: borrowing JSON.EncodingContext) throws(JSONEncodingError) -> JSON.Value
  }

  /// A type representing errors that occur while encoding a JSON value.
  struct EncodingError: Error {
    var description: String
  }

  /// A type representing context used while encoding a value that conforms to
  /// ``JSON/Encodable``.
  struct EncodingContext: Sendable {
    /// Whether or not keys in JSON objects (in Swift, dictionaries) should be
    /// lexically sorted.
    ///
    /// If the value of this property is `false`, the order in which objects'
    /// keys are encoded is unspecified.
    var sortsObjectKeys = true

    /// Whether or not non-conforming floating-point values (infinity and NaN)
    /// should be encoded as strings.
    ///
    /// If the value of this property is `false`, attempting to encode such a
    /// value will cause the testing library to throw an error.
    var encodesNonConformingFloatingPointValues = false
  }

  /// Encode a value as JSON.
  ///
  /// - Parameters:
  ///   - value: The value to encode.
  ///   - context: Context for the encoding session.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body` or by the encoding process.
  static func withEncoding<R>(
    of value: some JSON.Encodable,
    in context: JSON.EncodingContext = JSON.EncodingContext(),
    _ body: (UnsafeRawBufferPointer) throws -> R
  ) throws -> R {
    var buffer = [UInt8]()
    try value.jsonValue(in: context).encode(in: context, into: &buffer)

    return try buffer.withUnsafeBytes { json in
#if DEBUG && !SWT_NO_FILE_IO && canImport(Foundation)
      if !json.isEmpty {
        let data = Data(bytesNoCopy: .init(mutating: json.baseAddress!), count: json.count, deallocator: .none)
        do {
          try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
          try? FileHandle.stderr.withLock {
            try FileHandle.stderr.write("Failed to correctly encode JSON for \(value): \(error)\n")
            try FileHandle.stderr.write(json)
            try FileHandle.stderr.write("\n")
          }
        }
      }
#endif
      return try body(json)
    }
  }

  /// Encode a value as JSON.
  ///
  /// - Parameters:
  ///   - value: The value to encode.
  ///   - context: Context for the encoding session.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body` or by the encoding process.
  ///
  /// This overload is used to disambiguate encoding for types that conform to
  /// both `Encodable` and ``JSON/Encodable``. It uses our encoder rather than
  /// Foundation's (`JSONEncoder`). To use `JSONEncoder`, explicitly pass the
  /// `userInfo` argument.
  static func withEncoding<R>(
    of value: some Swift.Encodable & JSON.Encodable,
    _ body: (UnsafeRawBufferPointer) throws -> R
  ) throws -> R {
    try withEncoding(of: value, in: JSON.EncodingContext(), body)
  }
}

// MARK: - CustomStringConvertible

extension JSON.EncodingError: CustomStringConvertible {}

// MARK: - Encoding JSON values

extension JSON.Value {
  /// Constants for JSON keywords.
  private static let _true = Array("true".utf8)
  private static let _false = Array("false".utf8)
  private static let _null = Array("null".utf8)
  private static let _positiveInfinity = Array(JSON.positiveInfinityString.utf8)
  private static let _negativeInfinity = Array(JSON.negativeInfinityString.utf8)
  private static let _nan = Array(JSON.nanString.utf8)

  /// Encode the given string and append it to the given buffer.
  ///
  /// - Parameters:
  ///   - string: The string to encode.
  ///   - buffer: The buffer to which the encoded form of `string` should be
  ///     appended.
  private static func _encode(_ string: String, into buffer: inout [UInt8]) {
    func requiresEscaping(_ byte: UInt8) -> Bool {
      // All printable ASCII characters are in the range 0x20 ..< 0x7F. UTF-8
      // bytes outside ASCII do not require escaping.
      return byte < 0x20 || byte == 0x7F || byte == UInt8(ascii: #"\"#) || byte == UInt8(ascii: #"""#)
    }

    buffer.append(UInt8(ascii: #"""#))
    defer {
      buffer.append(UInt8(ascii: #"""#))
    }

    // Fast path for strings where none of the UTF-8 code points need escaping.
    if string.isContiguousUTF8 {
      var string = string
      let tookFastPath = string.withUTF8 { utf8 in
        let allFast = !utf8.contains(where: requiresEscaping)
        if _fastPath(allFast) {
          buffer += utf8
        }
        return allFast
      }
      if tookFastPath {
        return
      }
    }

    for c in string.utf8 {
      if requiresEscaping(c) {
        buffer.append(UInt8(ascii: #"\"#))
      }
      switch c {
      case UInt8(ascii: #"\"#), UInt8(ascii: #"""#):
        // These characters can be escaped verbatim. They can also be escaped as
        // Unicode code points, but that's not very idiomatic for JSON.
        buffer.append(c)
      default:
        buffer.append(UInt8(ascii: "u"))
        buffer.append(UInt8(ascii: "0"))
        buffer.append(UInt8(ascii: "0"))

        func encodeNybble(_ nybble: UInt8, to buffer: inout [UInt8]) {
          if nybble < 0xA {
            buffer.append(UInt8(ascii: "0") + nybble)
          } else {
            buffer.append(UInt8(ascii: "A") + (nybble - 0xA))
          }
        }
        encodeNybble((c & 0xF0) >> 4, to: &buffer)
        encodeNybble((c & 0x0F) >> 0, to: &buffer)
      }
    }
  }

  /// Encode the given number and append it to the given buffer.
  ///
  /// - Parameters:
  ///   - number: The number to encode.
  ///   - context: Context for the encoding session.
  ///   - buffer: The buffer to which the encoded form of `number` should be
  ///     appended.
  ///
  /// - Throws: If `number` is a non-conforming floating-point value and the
  ///   value of `context.encodesNonConformingFloatingPointValues` is `false`.
  private static func _encode(_ number: JSON.Number, in context: JSON.EncodingContext, into buffer: inout [UInt8]) throws(JSON.EncodingError) {
    switch number {
    case let .signedInteger(value):
      if value < 0 {
        buffer.append(UInt8(ascii: "-"))
      }
      try _encode(.unsignedInteger(value.magnitude), in: context, into: &buffer)
    case let .unsignedInteger(value):
      let originalValue = value
      if value == 0 {
        buffer.append(UInt8(ascii: "0"))
      } else {
        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 128) { digits in
          var i = 0
          var value = value
          while value > 0 {
            assert(i < digits.count, "Ran out of space in a \(digits.count)-byte buffer to hold the string representation of \(originalValue). \(fileABugMessage)")
            defer { i += 1 }

            let digit: JSON.Number.UnsignedInteger
            (value, digit) = value.quotientAndRemainder(dividingBy: 10)
            digits[i] = UInt8(ascii: "0") + UInt8(truncatingIfNeeded: digit)
          }

          buffer += digits[0 ..< i].reversed()
        }
      }
    case let .floatingPoint(value):
      if value.isNaN {
        guard context.encodesNonConformingFloatingPointValues else {
          throw JSON.EncodingError(description: "JSON does not support encoding NaN values by default.")
        }
        buffer += Self._nan
      } else if value.isInfinite {
        guard context.encodesNonConformingFloatingPointValues else {
          throw JSON.EncodingError(description: "JSON does not support encoding infinite values by default.")
        }
        buffer += value > 0 ? Self._positiveInfinity : Self._negativeInfinity
      } else {
        buffer += String(describing: value).utf8
      }
    }
  }

  /// Encode the given JSON object (in Swift, dictionary) and append it to the
  /// given buffer.
  ///
  /// - Parameters:
  ///   - object: The JSON object to encode.
  ///   - context: Context for the encoding session.
  ///   - buffer: The buffer to which the encoded form of `object` should be
  ///     appended.
  ///
  /// - Throws: Any error thrown while encoding one of the keys or values in
  ///   `object`.
  private static func _encode(_ object: [String: JSON.Value], in context: JSON.EncodingContext, into buffer: inout [UInt8]) throws(JSON.EncodingError) {
    buffer.append(UInt8(ascii: "{"))
    defer {
      buffer.append(UInt8(ascii: "}"))
    }
    var isFirst = true
    func encodeValue(_ value: JSON.Value, forKey key: String) throws(JSON.EncodingError) {
      if isFirst {
        isFirst = false
      } else {
        buffer.append(UInt8(ascii: ","))
      }
      Self._encode(key, into: &buffer)
      buffer.append(UInt8(ascii: ":"))
      try value.encode(in: context, into: &buffer)
    }
    if context.sortsObjectKeys {
      let sorted = object.sorted(by: { $0.key < $1.key })
      for (key, value) in sorted {
        try encodeValue(value, forKey: key)
      }
    } else {
      for (key, value) in object {
        try encodeValue(value, forKey: key)
      }
    }
  }

  /// Encode the given array and append it to the given buffer.
  ///
  /// - Parameters:
  ///   - array: The array to encode.
  ///   - context: Context for the encoding session.
  ///   - buffer: The buffer to which the encoded form of `array` should be
  ///     appended.
  ///
  /// - Throws: Any error thrown while encoding one of the elements of `array`.
  private static func _encode(_ array: [JSON.Value], in context: JSON.EncodingContext, into buffer: inout [UInt8]) throws(JSON.EncodingError) {
    buffer.append(UInt8(ascii: "["))
    defer {
      buffer.append(UInt8(ascii: "]"))
    }
    var isFirst = true
    for value in array {
      if isFirst {
        isFirst = false
      } else {
        buffer.append(UInt8(ascii: ","))
      }
      try value.encode(in: context, into: &buffer)
    }
  }

  /// Encode this JSON value and append it to the given buffer.
  ///
  /// - Parameters:
  ///   - context: Context for the encoding session.
  ///   - buffer: The buffer to which the encoded form of `self` should be
  ///     appended.
  ///
  /// - Throws: Any error thrown while encoding this JSON value.
  fileprivate func encode(in context: JSON.EncodingContext, into buffer: inout [UInt8]) throws(JSON.EncodingError) {
    switch self {
    case let .string(string):
      Self._encode(string, into: &buffer)
    case let .number(number):
      try Self._encode(number, in: context, into: &buffer)
    case let .object(object):
      try Self._encode(object, in: context, into: &buffer)
    case let .array(array):
      try Self._encode(array, in: context, into: &buffer)
    case let .bool(bool):
      buffer += bool ? Self._true : Self._false
    case .null:
      buffer += Self._null
    }
  }
}

// MARK: - Basic JSON.Encodable conformances

extension JSON.Value: JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) -> JSON.Value {
    self
  }
}

extension JSON.Number: JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) -> JSON.Value {
    .number(self)
  }
}

extension String: JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) -> JSON.Value {
    .string(self)
  }
}

extension SignedInteger where Self: FixedWidthInteger & JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) -> JSON.Value {
    guard let value = JSON.Number.SignedInteger(exactly: self) else {
      let bitWidth = JSON.Number.SignedInteger.bitWidth
      preconditionFailure("Could not convert signed integer \(self) to an instance of 'Int\(bitWidth)'. \(fileABugMessage)")
    }
    return .number(.signedInteger(value))
  }
}

extension Int8: JSON.Encodable {}
extension Int16: JSON.Encodable {}
extension Int32: JSON.Encodable {}
extension Int64: JSON.Encodable {}
extension Int: JSON.Encodable {}

extension UnsignedInteger where Self: FixedWidthInteger & JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) -> JSON.Value {
    guard let value = JSON.Number.UnsignedInteger(exactly: self) else {
      let bitWidth = JSON.Number.UnsignedInteger.bitWidth
      preconditionFailure("Could not convert unsigned integer \(self) to an instance of 'UInt\(bitWidth)'. \(fileABugMessage)")
    }
    return .number(.unsignedInteger(value))
  }
}

extension UInt8: JSON.Encodable {}
extension UInt16: JSON.Encodable {}
extension UInt32: JSON.Encodable {}
extension UInt64: JSON.Encodable {}
extension UInt: JSON.Encodable {}

extension JSON.Number.FloatingPoint: JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) -> JSON.Value {
    .number(.floatingPoint(self))
  }
}

extension Dictionary: JSON.Encodable where Key == String, Value: JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) throws(Value.JSONEncodingError) -> JSON.Value {
    try .object(
      self.mapValues { [context = copy context] value throws(Value.JSONEncodingError) in
        try value.jsonValue(in: context)
      }
    )
  }
}

extension Array: JSON.Encodable where Element: JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) throws(Element.JSONEncodingError) -> JSON.Value {
    try .array(
      self.map { [context = copy context] element throws(Element.JSONEncodingError) in
        try element.jsonValue(in: context)
      }
    )
  }
}

extension Bool: JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) -> JSON.Value {
    .bool(self)
  }
}

#if !SWT_NO_CODABLE
// MARK: - Encodable conveniences

extension JSON.Value: Encodable {
  /// A type representing any (string) coding key, for use when encoding
  /// arbitrary dictionaries.
  private struct _AnyCodingKey: Sendable, CodingKey {
    var stringValue: String

    init(stringValue: String) {
      self.stringValue = stringValue
    }

    init?(intValue: Int) {
      return nil
    }

    var intValue: Int? {
      nil
    }
  }

  func encode(to encoder: any Encoder) throws {
    switch self {
    case let .string(string):
      var container = encoder.singleValueContainer()
      try container.encode(string)
    case let .number(number):
      var container = encoder.singleValueContainer()
      switch number {
      case let .signedInteger(value):
        try container.encode(value)
      case let .unsignedInteger(value):
        try container.encode(value)
      case let .floatingPoint(value):
        try container.encode(value)
      }
    case let .object(object):
      var container = encoder.container(keyedBy: _AnyCodingKey.self)
      for (key, value) in object {
        try container.encode(value, forKey: _AnyCodingKey(stringValue: key))
      }
    case let .array(array):
      var container = encoder.unkeyedContainer()
      try container.encode(contentsOf: array)
    case let .bool(bool):
      var container = encoder.singleValueContainer()
      try container.encode(bool)
    case .null:
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    }
  }
}

extension Encoder {
  /// Encode the given value into this encoder using our JSON-encoding logic.
  ///
  /// - Parameters:
  ///   - value: The value to encode.
  ///
  /// - Throws: Any error that prevented encoding `value`.
  ///
  /// You can use this function to simplify the implementation of types that
  /// conform to both `Encodable` and ``JSON/Encodable``. Implement
  /// ``JSON/Encodable/jsonValue(in:)``, then implement `encode(to:)` such that
  /// it calls this function:
  ///
  /// ```swift
  /// func encode(to encoder: any Encoder) throws {
  ///   try encoder.encodeJSONEncodableValue(self)
  /// }
  /// ```
  func encodeJSONEncodableValue(_ value: some JSON.Encodable) throws {
    var context = JSON.EncodingContext()
    if (userInfo[.allowNonConformingFloatingPointValuesUserInfoKey] as? Bool) == true {
      context.encodesNonConformingFloatingPointValues = true
    }
    let jsonValue = try value.jsonValue(in: context)
    var container = self.singleValueContainer()
    try container.encode(jsonValue)
  }
}
#endif
