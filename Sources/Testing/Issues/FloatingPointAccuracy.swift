//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

// MARK: - Abstract operator definitions

/// The precedence group used by the `±` operator.
///
/// This precedence group allows for expressions like `(1.0 == 2.0) ± 5.0`.
precedencegroup AccuracyPrecedence {
  associativity: left
  lowerThan: AssignmentPrecedence
}

/// The `±` operator.
///
/// This operator allows for expressions like `(1.0 == 2.0) ± 5.0`.
infix operator ±: AccuracyPrecedence

/// The `+-` operator.
///
/// This operator allows for expressions like `(1.0 == 2.0) ± 5.0`. It is a
/// replacement for `±` that can be used when that character is unavailable or
/// difficult to type.
infix operator +-: AccuracyPrecedence

// MARK: - Storage for operands

@frozen public struct FloatingPointComparison<F> where F: FloatingPoint {
  @usableFromInline var lhs: F
  @usableFromInline var rhs: F

  @usableFromInline enum Operator: Sendable {
    case equals
    case doesNotEqual
  }
  @usableFromInline var `operator`: Operator

  @usableFromInline init(lhs: F, rhs: F, operator: Operator) {
    self.lhs = lhs
    self.rhs = rhs
    self.operator = `operator`
  }

  @usableFromInline func callAsFunction(accuracy: F) -> Bool {
    let diff = (lhs - rhs).magnitude
    return switch `operator` {
    case .equals:
      diff <= accuracy
    case .doesNotEqual:
      diff > accuracy
    }
  }
}

@available(*, unavailable)
extension FloatingPointComparison: Sendable {}

extension FloatingPointComparison: CustomTestStringConvertible {
  public var testDescription: String {
    switch `operator` {
    case .equals:
      "(\(lhs) == \(rhs))"
    case .doesNotEqual:
      "(\(lhs) != \(rhs))"
    }
  }
}

// MARK: - Comparison operator overloads

@_disfavoredOverload
@inlinable public func ==<F>(_lhs: F, rhs: F) -> FloatingPointComparison<F> where F: FloatingPoint {
  FloatingPointComparison(lhs: _lhs, rhs: rhs, operator: .equals)
}

@_disfavoredOverload
@inlinable public func !=<F>(_lhs: F, rhs: F) -> FloatingPointComparison<F> where F: FloatingPoint {
  FloatingPointComparison(lhs: _lhs, rhs: rhs, operator: .doesNotEqual)
}

// MARK: - Accuracy operators

/// The `±` operator.
///
/// This operator allows for expressions like `(1.0 == 2.0) ± 5.0`. Use it when
/// comparing floating-point values that may have accumulated error:
///
/// ```swift
/// let totalOrderCost = allFoods.reduce(into: 0.0, +=)
/// #expect(totalOrderCost == 100.00 ± 0.01)
/// ```
///
/// This operator can be used after the `==` and `!=` operators to compare two
/// floating-point values of the same type. It can also be spelled `+-` (the two
/// spellings are exactly equivalent.)
@inlinable public func ±<F>(comparison: FloatingPointComparison<F>, accuracy: F) -> Bool where F: FloatingPoint {
  comparison(accuracy: accuracy)
}

/// The `+-` operator.
///
/// This operator allows for expressions like `(1.0 == 2.0) ± 5.0`. It is a
/// replacement for `±` that can be used when that character is unavailable or
/// difficult to type.
@inlinable public func +-<F>(_comparison: FloatingPointComparison<F>, accuracy: F) -> Bool where F: FloatingPoint {
  _comparison(accuracy: accuracy)
}
