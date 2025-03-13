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
  protocol Serializable {
    /// A type representing the result of by ``makeJSON()``.
    associatedtype JSONBytes: Collection where JSONBytes.Element == UInt8

    /// Serialize this value as JSON.
    ///
    /// - Returns: The sequence of bytes representing this value as JSON.
    ///
    /// - Throws: Any error that prevented serializing this value.
    func makeJSON() throws -> JSONBytes
  }
}

extension JSON.Serializable {
  /// Write the JSON representation of this value to the given file handle.
  ///
  /// - Parameters:
  ///   - file: The file to write to. A trailing newline is not written.
  ///   - flushAfterward: Whether or not to flush the file (with `fflush()`)
  ///     after writing. If `true`, `fflush()` is called even if an error
  ///     occurred while writing.
  ///
  /// - Throws: Any error that occurred while writing `bytes`. If an error
  ///   occurs while flushing the file, it is not thrown.
  func writeJSON(to file: borrowing FileHandle, flushAfterward: Bool = true) throws {
    try file.write(makeJSON(), flushAfterward: flushAfterward)
  }
}

// MARK: - Arbitrary bytes

extension JSON {
  struct Verbatim<S>: JSON.Serializable where S: Collection, S.Element == UInt8 {
    private var _bytes: S

    init(_ bytes: S) {
      _bytes = bytes
    }

    func makeJSON() throws -> S {
      _bytes
    }
  }
}

// MARK: - Scalars

extension Bool: JSON.Serializable {
  func makeJSON() throws -> UnsafeBufferPointer<UInt8> {
    let stringValue: StaticString = self ? "true" : "false"
    return UnsafeBufferPointer(start: stringValue.utf8Start, count: stringValue.utf8CodeUnitCount)
  }
}

extension Numeric where Self: CustomStringConvertible & JSON.Serializable {
  func makeJSON() throws -> String.UTF8View {
    String(describing: self).utf8
  }
}

extension Int: JSON.Serializable {}
extension UInt64: JSON.Serializable {}
extension Double: JSON.Serializable {}

extension String: JSON.Serializable {
  func makeJSON() throws -> [UInt8] {
    var result = [UInt8]()

    let scalars = self.unicodeScalars
    result.reserveCapacity(scalars.underestimatedCount + 2)

    do {
      result.append(UInt8(ascii: #"""#))
      defer {
        result.append(UInt8(ascii: #"""#))
      }

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

    return result
  }
}

// MARK: - Arrays

extension Array: JSON.Serializable where Element: JSON.Serializable {
  func makeJSON() throws -> [UInt8] {
    var result = [UInt8]()

    do {
      result.append(UInt8(ascii: "["))
      defer {
        result.append(UInt8(ascii: "]"))
      }

      result += try self.lazy.map { element in
        try element.makeJSON()
      }.joined(separator: CollectionOfOne(UInt8(ascii: ",")))
    }

    return result
  }
}

// MARK: - Dictionaries

extension Dictionary: JSON.Serializable where Key == String, Value: JSON.Serializable {
  func makeJSON() throws -> [UInt8] {
    var result = [UInt8]()

    do {
      result.append(UInt8(ascii: #"{"#))
      defer {
        result.append(UInt8(ascii: #"}"#))
      }

      result += try self.sorted { lhs, rhs in
        lhs.key < rhs.key
      }.map { key, value in
        let serializedKey = try key.makeJSON()
        let serializedValue = try value.makeJSON()
        return serializedKey + CollectionOfOne(UInt8(ascii: ":")) + serializedValue
      }.joined(separator: CollectionOfOne(UInt8(ascii: #","#)))
    }

    return result
  }
}

extension JSON {
  typealias HeterogenousDictionary = Dictionary<String, JSON.Verbatim<[UInt8]>>
}

extension JSON.HeterogenousDictionary {
  @discardableResult
  mutating func updateValue(_ value: some JSON.Serializable, forKey key: String) throws -> Value? {
    let serializedValue = try JSON.Verbatim(Array(value.makeJSON()))
    return updateValue(serializedValue as Value, forKey: key)
  }
}

// MARK: - RawRepresentable

extension RawRepresentable where Self: JSON.Serializable, RawValue: JSON.Serializable {
  func makeJSON() throws -> RawValue.JSONBytes {
    try rawValue.makeJSON()
  }
}
