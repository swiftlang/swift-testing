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
  /// A protocol describing a value that can be serialized as JSON.
  protocol Serializable {
    /// Serialize this instance as a JSON value.
    ///
    /// - Returns: A JSON value representing this instance.
    func makeJSONValue() -> Value
  }
}

extension JSON.Value: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    self
  }
}

// MARK: - Scalars

extension Bool: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    .bool(self)
  }
}

extension SignedInteger where Self: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    .int64(Int64(self))
  }
}

extension Int8: JSON.Serializable {}
extension Int16: JSON.Serializable {}
extension Int32: JSON.Serializable {}
extension Int64: JSON.Serializable {}
@available(*, unavailable)
extension Int128: JSON.Serializable {}
extension Int: JSON.Serializable {}

extension UnsignedInteger where Self: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    .uint64(UInt64(self))
  }
}

extension UInt8: JSON.Serializable {}
extension UInt16: JSON.Serializable {}
extension UInt32: JSON.Serializable {}
extension UInt64: JSON.Serializable {}
@available(*, unavailable)
extension UInt128: JSON.Serializable {}
extension UInt: JSON.Serializable {}

extension Double: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    .double(self)
  }
}

extension String: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    .string(self)
  }
}

// MARK: - Arrays

extension Array: JSON.Serializable where Element: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    let arrayCopy = self.map { $0.makeJSONValue() }
    return .array(arrayCopy)
  }
}

// MARK: - Dictionaries

extension Dictionary: JSON.Serializable where Key == String, Value: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    let dictCopy = self.mapValues { $0.makeJSONValue() }
    return .object(dictCopy)
  }
}

// MARK: - Optional and RawRepresentable

extension Optional: JSON.Serializable where Wrapped: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    guard let value = self else {
      return .null
    }
    return value.makeJSONValue()
  }
}

extension RawRepresentable where Self: JSON.Serializable, RawValue: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    rawValue.makeJSONValue()
  }
}
