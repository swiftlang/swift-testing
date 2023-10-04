//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A protocol describing types with a custom string representation when
/// presented as part of a test's output.
///
/// Values whose types conform to this protocol use it to describe themselves
/// when they are present as part of the output of a test. For example, this
/// protocol affects the display of values that are passed as arguments to test
/// functions or that are elements of an expectation failure.
///
/// By default, the testing library converts values to strings using
/// `String(describing:)`. The resulting string may be inappropriate for some
/// types and their values. If the type of the value is made to conform to
/// ``CustomTestStringConvertible``, then the value of its ``testDescription``
/// property will be used instead.
///
/// For example, consider the following type:
///
/// ```swift
/// enum Food {
///   case paella
///   case oden
///   case ragu
///   ...
/// }
/// ```
///
/// If an array of cases from this enumeration is passed to a parameterized test
/// function:
///
/// ```swift
/// @Test(arguments: [.paella, .oden, .ragu])
/// func isDelicious(_ food: Food) { ... }
/// ```
///
/// Then the values in the array need to be presented in the test output, but
/// the default description of a value may not be adequately descriptive:
///
/// ```
/// ◇ Passing argument food → .paella to isDelicious(\_:)
/// ◇ Passing argument food → .oden to isDelicious(\_:)
/// ◇ Passing argument food → .ragu to isDelicious(\_:)
/// ```
///
/// By adopting ``CustomTestStringConvertible``, customized descriptions can be
/// included:
///
/// ```swift
/// extension Food: CustomTestStringConvertible {
///   var testDescription: String {
///     switch self {
///     case .paella:
///       "paella valenciana"
///     case .oden:
///       "おでん"
///     case .ragu:
///       "ragù alla bolognese"
///     }
///   }
/// }
/// ```
///
/// The presentation of these values will then reflect the value of the
/// ``testDescription`` property:
///
/// ```
/// ◇ Passing argument food → paella valenciana to isDelicious(\_:)
/// ◇ Passing argument food → おでん to isDelicious(\_:)
/// ◇ Passing argument food → ragù alla bolognese to isDelicious(\_:)
/// ```
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
  /// Describe a case from an enumeration declared in C, Objective-C, or C++.
  ///
  /// - Parameters:
  ///   - value: The value to describe.
  ///
  /// - Returns: A description of `value`, or `nil` if `value` does not appear
  ///   to be a C enumeration case.
  private static func _describeCEnumCase(_ value: some RawRepresentable) -> String? {
    // If the default description equals the name of the type of the value, that
    // type conforms to RawRepresentable, and that type is an enum, then we're
    // presumably dealing with a C enumeration. Note that String(describing:)
    // will produce a different string for `some RawRepresentable` than for
    // `Any`, so we're casting back to `Any` here in order to do the comparison.
    let typeDesc = String(describing: type(of: value))
    if String(describing: value as Any) == typeDesc {
      return "\(typeDesc)(rawValue: \(String(describingForTest: value.rawValue)))"
    }
    return nil
  }

  /// Initialize this instance so that it can be presented in a test's output.
  ///
  /// - Parameters:
  ///   - value: The value to describe.
  ///
  /// ## See Also
  ///
  /// - ``CustomTestStringConvertible``
  public init(describingForTest value: Any) {
    if let value = value as? any CustomTestStringConvertible {
      self = value.testDescription
    } else if let value = value as? any CustomStringConvertible {
      self.init(describing: value)
    } else if Mirror(reflecting: value).displayStyle == .enum {
      if let value = value as? any RawRepresentable, let cEnumDescription = Self._describeCEnumCase(value) {
        self = cEnumDescription
      } else {
        // Add a leading period to enumeration cases to more closely match their
        // source representation. This cannot be done generically because
        // enumerations do not universally or automatically conform to some
        // protocol that can be detected at runtime.
        self = ".\(value)"
      }
    } else {
      // Use the generic description of the value.
      self.init(describing: value)
    }
  }
}

// MARK: - Built-in implementations

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

extension CustomTestStringConvertible where Self: StringProtocol {
  public var testDescription: String {
    "\"\(self)\""
  }
}

extension String: CustomTestStringConvertible {}
extension Substring: CustomTestStringConvertible {}
