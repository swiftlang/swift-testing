//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A protocol describing types with a custom string representation when
/// presented as part of a test's output.
///
/// ## See Also
///
/// - ``Swift/String/init(describingForTest:)``
public protocol CustomTestStringConvertible {
  /// A description of this instance to use when presenting it in a test's
  /// output.
  ///
  /// Do not use this property directly. To get the test description of a value,
  /// use ``Swift/String/init(describingForTest:)``.
  var testDescription: String { get }

#if hasFeature(Embedded)
  /// A description of this type.
  ///
  /// - Warning: This function is used to implement value capturing under
  ///   Embedded Swift. Do not use it or provide an implementation for it.
  static var __testingTypeInfo: Any? { get }

  /// A description of this value's type.
  ///
  /// - Warning: This function is used to implement value capturing under
  ///   Embedded Swift. Do not use it or provide an implementation for it.
  var __testingTypeInfo: Any? { get }
#endif
}

extension String {
  /// Initialize this instance so that it can be presented in a test's output.
  ///
  /// - Parameters:
  ///   - value: The value to describe.
  ///
  /// ## See Also
  ///
  /// - ``CustomTestStringConvertible``
  @_unavailableInEmbedded
  public init(describingForTest value: some Any) {
#if !hasFeature(Embedded)
    // The mangled type name SPI doesn't handle generic types very well, so we
    // ask for the dynamic type of `value` (type(of:)) instead of just T.self.
    lazy var valueTypeInfo = TypeInfo(describingTypeOf: value)
    if let value = value as? any CustomTestStringConvertible {
      self = value.testDescription
    } else if let value = value as? any CustomStringConvertible {
      self.init(describing: value)
    } else if let value = value as? any TextOutputStreamable {
      self.init(describing: value)
    } else if let value = value as? any CustomDebugStringConvertible {
      self.init(reflecting: value)
    } else if let value = value as? any Any.Type {
      self = _testDescription(of: value)
    } else if let value = value as? any RawRepresentable, let type = valueTypeInfo.type, valueTypeInfo.isImportedFromC {
      // Present raw-representable C types, which we assume to be imported
      // enumerations, in a consistent fashion. The case names of C enumerations
      // are not statically visible, so instead present the enumeration type's
      // name along with the raw value of `value`.
      let typeName = String(describingForTest: type)
      self = "\(typeName)(rawValue: \(String(describingForTest: value.rawValue)))"
    } else if valueTypeInfo.isSwiftEnumeration {
      // Add a leading period to enumeration cases to more closely match their
      // source representation. SEE: _adHocPrint_unlocked() in the stdlib.
      self = ".\(value)"
    } else {
      // Use the generic description of the value.
      self.init(describing: value)
    }
#else
    swt_unreachable()
#endif
  }

  /// Initialize this instance so that it can be presented in a test's output.
  ///
  /// - Parameters:
  ///   - value: The value to describe.
  ///
  /// @Comment {
  ///   This overload is used to trivially describe values that are statically
  ///   known to conform to ``CustomTestStringConvertible``.
  /// }
  ///
  /// ## See Also
  ///
  /// - ``CustomTestStringConvertible``
  @_documentation(visibility: private)
  @inlinable public init(describingForTest value: borrowing some CustomTestStringConvertible) {
    self = value.testDescription
  }

#if hasFeature(Embedded)
  public init(describingForTest value: borrowing some CustomStringConvertible & CustomTestStringConvertible) {
    self = value.testDescription
  }

  public init(describingForTest value: borrowing some CustomStringConvertible) {
    self = value.description
  }

  public init(describingForTest value: borrowing some CustomDebugStringConvertible & CustomTestStringConvertible) {
    self = value.testDescription
  }

  public init(describingForTest value: borrowing some CustomDebugStringConvertible) {
    self = value.debugDescription
  }

  public init(describingForTest value: borrowing some CustomStringConvertible & CustomDebugStringConvertible & CustomTestStringConvertible) {
    self = value.testDescription
  }

  public init(describingForTest value: borrowing some CustomStringConvertible & CustomDebugStringConvertible) {
    self = value.description
  }

  @_disfavoredOverload
  @available(*, deprecated, message: "String representations of arbitrary values are not supported in Embedded Swift")
  init(describingForTest value: borrowing some ~Copyable & ~Escapable) {
    // FIXME: need some sort of description functionality for arbitrary values
    self = UnavailableInEmbeddedSwift.testDescription
  }

  init(describingForTest value: (some ~Copyable & ~Escapable).Type) {
    // FIXME: need some sort of description functionality for types
    self = UnavailableInEmbeddedSwift.testDescription
  }

  init(describingForTest error: any Error) {
    let domain = error._domain
    if domain == "(unknown domain in Embedded Swift)" { // TODO: avoid hard-coding
      self = "error \(error._code) in unknown domain"
    } else {
      self = "error \(error._code) in domain '\(domain)'"
    }
  }
#endif
}

// MARK: - Built-in implementations

#if !hasFeature(Embedded)
/// The _de facto_ implementation of ``CustomTestStringConvertible`` for a
/// metatype value.
///
/// - Parameters:
///   - type: The type to describe.
///
/// - Returns: The description of `type`, as produced by
///   ``Swift/String/init(describingForTest:)``.
private func _testDescription(of type: any Any.Type) -> String {
  TypeInfo(describing: type).unqualifiedName
}

extension Optional: CustomTestStringConvertible {
  public var testDescription: String {
    switch self {
    case let .some(unwrappedValue):
      String(describingForTest: unwrappedValue)
    case nil:
      _OptionalNilComparisonType.testDescription
    }
  }
}
#else
extension CustomTestStringConvertible {
  public static var __testingTypeInfo: Any? {
    nil
  }

  public var __testingTypeInfo: Any? {
    Self.__testingTypeInfo
  }
}

extension TypeInfo {
  init?(describing type: (some CustomTestStringConvertible).Type) {
    guard let typeInfo = type.__testingTypeInfo as? TypeInfo else {
      return nil
    }
    self = typeInfo
  }

  init?(describingTypeOf value: any CustomTestStringConvertible) {
    guard let typeInfo = value.__testingTypeInfo as? TypeInfo else {
      return nil
    }
    self = typeInfo
  }
}

extension Optional: CustomTestStringConvertible where Wrapped: CustomTestStringConvertible {
  public var testDescription: String {
    switch self {
    case let .some(unwrappedValue):
      String(describingForTest: unwrappedValue)
    case nil:
      _OptionalNilComparisonType.testDescription
    }
  }

  public static var __testingTypeInfo: Any? {
    let wrappedTypeInfo = TypeInfo(describing: Wrapped.self) ?? .any
    return TypeInfo(
      fullyQualifiedNameComponents: ["Swift", "Optional<\(wrappedTypeInfo.fullyQualifiedName)>"],
      unqualifiedName: "Optional<\(wrappedTypeInfo.unqualifiedName)>"
    )
  }
}
#endif

extension _OptionalNilComparisonType: CustomTestStringConvertible {
  @inlinable static var testDescription: String {
    "nil"
  }

  public var testDescription: String {
    Self.testDescription
  }

#if hasFeature(Embedded)
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "_OptionalNilComparisonType"])
  }
#endif
}

#if hasFeature(Embedded)
// MARK: - Arithmetic types (Embedded Swift only)

extension Numeric where Self: CustomStringConvertible & CustomTestStringConvertible {
  public var testDescription: String {
    String(describing: self)
  }
}

extension SignedInteger where Self: CustomTestStringConvertible & FixedWidthInteger {
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "Int\(Self.bitWidth)"])
  }
}

extension UnsignedInteger where Self: CustomTestStringConvertible & FixedWidthInteger {
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "UInt\(Self.bitWidth)"])
  }
}

extension Int: CustomTestStringConvertible {
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "Int"])
  }
}
extension Int8: CustomTestStringConvertible {}
extension Int16: CustomTestStringConvertible {}
extension Int32: CustomTestStringConvertible {}
extension Int64: CustomTestStringConvertible {}
extension Int128: CustomTestStringConvertible {}

extension UInt: CustomTestStringConvertible {
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "UInt"])
  }
}
extension UInt8: CustomTestStringConvertible {}
extension UInt16: CustomTestStringConvertible {}
extension UInt32: CustomTestStringConvertible {}
extension UInt64: CustomTestStringConvertible {}
extension UInt128: CustomTestStringConvertible {}

extension Float16: CustomTestStringConvertible {
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "Float16"])
  }
}

extension Float32: CustomTestStringConvertible  {
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "Float"])
  }
}

extension Float64: CustomTestStringConvertible  {
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "Double"])
  }
}

#if arch(i386) || arch(x86_64)
extension Float80: CustomTestStringConvertible  {
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "Float80"])
  }
}
#endif

extension Bool: CustomTestStringConvertible {
  public var testDescription: String {
    self ? "true" : "false"
  }

  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "Bool"])
  }
}

// MARK: - Pointer types (Embedded Swift only)

extension _Pointer where Self: CustomTestStringConvertible {
  public var testDescription: String {
    let bitPattern = UInt(bitPattern: self)
    return "0x\(String(bitPattern, radix: 16))"
  }
}

extension UnsafeRawPointer: CustomTestStringConvertible {
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "UnsafeRawPointer"])
  }
}
extension UnsafeMutableRawPointer: CustomTestStringConvertible {
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "UnsafeMutableRawPointer"])
  }
}
extension UnsafePointer: CustomTestStringConvertible {
  public static var __testingTypeInfo: Any? {
    let pointeeTypeInfo = TypeInfo.any
    return TypeInfo(
      fullyQualifiedNameComponents: ["Swift", "UnsafePointer<\(pointeeTypeInfo.fullyQualifiedName)>"],
      unqualifiedName: "UnsafePointer<\(pointeeTypeInfo.unqualifiedName)>"
    )
  }
}
extension UnsafeMutablePointer: CustomTestStringConvertible {
  public static var __testingTypeInfo: Any? {
    let pointeeTypeInfo = TypeInfo.any
    return TypeInfo(
      fullyQualifiedNameComponents: ["Swift", "UnsafeMutablePointer<\(pointeeTypeInfo.fullyQualifiedName)>"],
      unqualifiedName: "UnsafeMutablePointer<\(pointeeTypeInfo.unqualifiedName)>"
    )
  }
}

extension OpaquePointer: CustomTestStringConvertible {
  public var testDescription: String {
    let bitPattern = UInt(bitPattern: self)
    return "0x\(String(bitPattern, radix: 16))"
  }

  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "OpaquePointer"])
  }
}

extension UnsafeRawBufferPointer: CustomTestStringConvertible {
  public var testDescription: String {
    "UnsafeRawBufferPointer(start: \(String(describingForTest: baseAddress)), count: \(count))"
  }

  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "UnsafeRawBufferPointer"])
  }
}

extension UnsafeMutableRawBufferPointer: CustomTestStringConvertible {
  public var testDescription: String {
    "UnsafeMutableRawBufferPointer(start: \(String(describingForTest: baseAddress)), count: \(count))"
  }

  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "UnsafeMutableRawBufferPointer"])
  }
}

extension UnsafeBufferPointer: CustomTestStringConvertible {
  public var testDescription: String {
    "UnsafeBufferPointer(start: \(String(describingForTest: baseAddress)), count: \(count))"
  }

  public static var __testingTypeInfo: Any? {
    let pointeeTypeInfo = TypeInfo.any
    return TypeInfo(
      fullyQualifiedNameComponents: ["Swift", "UnsafeBufferPointer<\(pointeeTypeInfo.fullyQualifiedName)>"],
      unqualifiedName: "UnsafeBufferPointer<\(pointeeTypeInfo.unqualifiedName)>"
    )
  }
}

extension UnsafeMutableBufferPointer: CustomTestStringConvertible {
  public var testDescription: String {
    "UnsafeMutableBufferPointer(start: \(String(describingForTest: baseAddress)), count: \(count))"
  }

  public static var __testingTypeInfo: Any? {
    let pointeeTypeInfo = TypeInfo.any
    return TypeInfo(
      fullyQualifiedNameComponents: ["Swift", "UnsafeMutableBufferPointer<\(pointeeTypeInfo.fullyQualifiedName)>"],
      unqualifiedName: "UnsafeMutableBufferPointer<\(pointeeTypeInfo.unqualifiedName)>"
    )
  }
}

// MARK: - Collection types (Embedded Swift only)

extension Sequence where Self: CustomStringConvertible & CustomTestStringConvertible, Self.Element: CustomTestStringConvertible {
  public var testDescription: String {
    String(describing: self)
  }
}

extension Array: CustomTestStringConvertible where Element: CustomTestStringConvertible {
  public var testDescription: String {
    let result = self.lazy
      .map { String(describingForTest: $0) }
      .joined(separator: ", ")
    return "[\(result)]"
  }

  public static var __testingTypeInfo: Any? {
    let elementTypeInfo = TypeInfo(describing: Element.self) ?? .any
    return TypeInfo(
      fullyQualifiedNameComponents: ["Swift", "Array<\(elementTypeInfo.fullyQualifiedName)>"],
      unqualifiedName: "Array<\(elementTypeInfo.unqualifiedName)>"
    )
  }
}

extension Dictionary: CustomTestStringConvertible where Key: CustomTestStringConvertible, Value: CustomTestStringConvertible {
  public var testDescription: String {
    let result = self.lazy
      .map { (String(describingForTest: $0), String(describingForTest: $1)) }
      .map { "\($0): \($1)" }
      .joined(separator: ",")
    return "[\(result)]"
  }

  public static var __testingTypeInfo: Any? {
    let keyTypeInfo = TypeInfo(describing: Key.self) ?? .any
    let valueTypeInfo = TypeInfo(describing: Value.self) ?? .any
    return TypeInfo(
      fullyQualifiedNameComponents: ["Swift", "Dictionary<\(keyTypeInfo.fullyQualifiedName), \(valueTypeInfo.fullyQualifiedName)>"],
      unqualifiedName: "Dictionary<\(keyTypeInfo.unqualifiedName), \(valueTypeInfo.unqualifiedName)>"
    )
  }
}
#endif

// MARK: - Strings

extension CustomTestStringConvertible where Self: StringProtocol {
  public var testDescription: String {
    "\"\(self)\""
  }
}

extension String: CustomTestStringConvertible {
#if hasFeature(Embedded)
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "String"])
  }
#endif
}

extension Substring: CustomTestStringConvertible {
#if hasFeature(Embedded)
  public static var __testingTypeInfo: Any? {
    TypeInfo(fullyQualifiedNameComponents: ["Swift", "Substring"])
  }
#endif
}

#if hasFeature(Embedded)
extension StaticString: CustomTestStringConvertible {
  public var testDescription: String {
    String(describing: self)
  }
}
#endif

#if !hasFeature(Embedded)
// MARK: - Ranges

extension ClosedRange: CustomTestStringConvertible {
  public var testDescription: String {
    "\(String(describingForTest: lowerBound)) ... \(String(describingForTest: upperBound))"
  }
}

extension PartialRangeFrom: CustomTestStringConvertible {
  public var testDescription: String {
    "\(String(describingForTest: lowerBound))..."
  }
}

extension PartialRangeThrough: CustomTestStringConvertible {
  public var testDescription: String {
    "...\(String(describingForTest: upperBound))"
  }
}

extension PartialRangeUpTo: CustomTestStringConvertible {
  public var testDescription: String {
    "..<\(String(describingForTest: upperBound))"
  }
}

extension Range: CustomTestStringConvertible {
  public var testDescription: String {
    "\(String(describingForTest: lowerBound)) ..< \(String(describingForTest: upperBound))"
  }
}
#endif
