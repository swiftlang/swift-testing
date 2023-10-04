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
/// ``CustomExpressionExpandable`` and the value of the instance's
/// ``descriptionInExpectationFailure`` property will be used instead.
public protocol CustomExpectationFailureRepresentable {
  /// A description of this instance to use when describing it in an expectation
  /// failure.
  var descriptionInExpectationFailure: String { get }
}

extension Optional: CustomExpectationFailureRepresentable {
  public var descriptionInExpectationFailure: String {
    switch self {
    case let .some(unwrappedValue):
      if let unwrappedValue = unwrappedValue as? any CustomExpectationFailureRepresentable {
        unwrappedValue.descriptionInExpectationFailure
      } else {
        String(describing: unwrappedValue)
      }
    case nil:
      "nil"
    }
  }
}

extension _OptionalNilComparisonType: CustomExpectationFailureRepresentable {
  public var descriptionInExpectationFailure: String {
    "nil"
  }
}
