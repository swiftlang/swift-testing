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
/// described in (for example) an expectation failure.
///
/// Values whose types conform to this protocol use it to describe themselves
/// when they are components of an expectation failure. For example, consider
/// the following type:
///
/// ```swift
/// struct Food {
///   func addSeasoning() -> Bool { ... }
/// }
/// ```
///
/// If an instance of this type is used in a failed expectation such as:
///
/// ```swift
/// #expect(food.addSeasoning())
/// ```
///
/// The expanded representation of the condition expression will be derived from
/// `String(describing: food)`. If that string is unsuitable for display in a
/// test's output, then the type can be made to conform to
/// ``CustomFailureStringConvertible`` and the value of the instance's
/// ``failureDescription`` property will be used instead.
///
/// ## See Also
///
/// - ``String/init(describingFailureOf:)``
public protocol CustomFailureStringConvertible {
  /// A description of this instance to use when describing it in an expectation
  /// failure.
  var failureDescription: String { get }
}

extension String {
  /// Initialize this instance to the description of a value as part of an
  /// expectation failure.
  ///
  /// - Parameters:
  ///   - value: The value to describe.
  ///
  /// ## See Also
  ///
  /// - ``CustomFailureStringConvertible``
  public init(describingFailureOf value: some Any) {
    if let value = value as? any CustomFailureStringConvertible {
      self = value.failureDescription
    } else {
      self.init(describing: value)
    }
  }
}

// MARK: - Built-in implementations

extension Optional: CustomFailureStringConvertible {
  public var failureDescription: String {
    switch self {
    case let .some(unwrappedValue):
      String(describingFailureOf: unwrappedValue)
    case nil:
      "nil"
    }
  }
}

extension _OptionalNilComparisonType: CustomFailureStringConvertible {
  public var failureDescription: String {
    "nil"
  }
}

extension CustomFailureStringConvertible where Self: StringProtocol {
  public var failureDescription: String {
    "\"\(self)\""
  }
}

extension String: CustomFailureStringConvertible {}
extension Substring: CustomFailureStringConvertible {}
