//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that aggregate sub-conditions in ``ConditionTrait`` which must be
/// satisfied for the testing library to enable a test.
///
/// To aggregate ``ConditionTrait`` please use following operator:
///
/// - ``Trait/&&(lhs:rhs)``
/// - ``Trait/||(lhs:rhs)``
///
/// @Metadata {
///   @Available(Swift, introduced: 6.2)
/// }
public struct GroupedConditionTraits: TestTrait, SuiteTrait {
  ///
  internal let expression: ConditionExpression

  internal init(_ expression: ConditionExpression) {
      self.expression = expression
  }

  public func prepare(for test: Test) async throws {
      try await evaluate()
  }

  @discardableResult
  public func evaluate() async throws -> Bool {
      let (result, skipInfo) = try await expression.evaluate(includeSkipInfo: true)
      if let skip = skipInfo, !result {
          throw skip
      }
      return result
  }
  
  internal indirect enum ConditionExpression {
    case trait(ConditionTrait)
    case and(ConditionExpression, ConditionExpression)
    case or(ConditionExpression, ConditionExpression)
  }
}
// MARK: - Trait Operator Overloads

public extension Trait where Self == GroupedConditionTraits {
  static func trait(_ t: ConditionTrait) -> Self {
    .init(.trait(t))
  }

  static func && (lhs: Self, rhs: ConditionTrait) -> Self {
    .init(.and(lhs.expression, .trait(rhs)))
  }

  static func && (lhs: Self, rhs: Self) -> Self {
    .init(.and(lhs.expression, rhs.expression))
  }

  static func || (lhs: Self, rhs: ConditionTrait) -> Self {
    .init(.or(lhs.expression, .trait(rhs)))
  }

  static func || (lhs: Self, rhs: Self) -> Self {
    .init(.or(lhs.expression, rhs.expression))
  }
}

extension GroupedConditionTraits.ConditionExpression {
  func evaluate(includeSkipInfo: Bool = false) async throws -> (Bool, SkipInfo?) {
    switch self {
    case .trait(let trait):
      var result = try await trait.evaluate()
      result =  trait.isInverted ? !result : result
      let skipInfo = result ? nil : SkipInfo(
        comment: trait.comments.first,
        sourceContext: SourceContext(backtrace: nil, sourceLocation: trait.sourceLocation)
      )
      return (result, skipInfo)

    case .and(let lhs, let rhs):
      let (leftResult, leftSkip) = try await lhs.evaluate(includeSkipInfo: includeSkipInfo)
      let (rightResult, rightSkip) = try await rhs.evaluate(includeSkipInfo: includeSkipInfo)
      let isEnabled = leftResult && rightResult
      return (isEnabled, isEnabled ? nil : leftSkip ?? rightSkip)

    case .or(let lhs, let rhs):
      let (leftResult, leftSkip) = try await lhs.evaluate(includeSkipInfo: includeSkipInfo)
      let (rightResult, rightSkip) = try await rhs.evaluate(includeSkipInfo: includeSkipInfo)
      let isEnabled = leftResult || rightResult
      return (isEnabled, isEnabled ? nil : leftSkip ?? rightSkip)
    }
  }
}
