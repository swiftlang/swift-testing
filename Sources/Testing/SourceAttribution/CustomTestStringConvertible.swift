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

#if hasFeature(Embedded)
  /// Initialize this instance so that it can be presented in a test's output.
  ///
  /// - Parameters:
  ///   - value: The value to describe.
  ///
  /// ## See Also
  ///
  /// - ``CustomTestStringConvertible``
  public init(describingForTest value: some CustomTestStringConvertible) {
    self = value.testDescription
  }

  /// Initialize this instance so that it can be presented in a test's output.
  ///
  /// - Parameters:
  ///   - value: The value to describe.
  ///
  /// ## See Also
  ///
  /// - ``CustomTestStringConvertible``
  @_disfavoredOverload
  @available(*, deprecated, message: "String representations of arbitrary values are not supported in Embedded Swift")
  @usableFromInline
  init(describingForTest value: borrowing some ~Copyable & ~Escapable) {
    // FIXME: need some sort of description functionality for arbitrary values
    self = "<unknown value>"
  }

  /// Initialize this instance so that it can be presented in a test's output.
  ///
  /// - Parameters:
  ///   - value: The value to describe.
  ///
  /// ## See Also
  ///
  /// - ``CustomTestStringConvertible``
  init(describingForTest value: (some ~Copyable & ~Escapable).Type) {
    // FIXME: need some sort of description functionality for types
    self = "<unknown type>"
  }

  init(describingForTest value: any Error) {
    // FIXME: need some sort of description functionality for errors
    self = "<unknown error>"
  }
#endif
}

// MARK: - Built-in implementations

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
      "nil"
    }
  }
}

extension _OptionalNilComparisonType: CustomTestStringConvertible {
  public var testDescription: String {
    "nil"
  }
}

// MARK: - Strings

extension CustomTestStringConvertible where Self: StringProtocol {
  public var testDescription: String {
    "\"\(self)\""
  }
}

extension String: CustomTestStringConvertible {}
extension Substring: CustomTestStringConvertible {}

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
