//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type to aggregate ``ConditionTrait`` in a way that it merge subcondition
/// instead of logical operation on conditions.
///
public struct GroupedConditionTraits: TestTrait, SuiteTrait {
  fileprivate let conditionTraits: [ConditionTrait]
  fileprivate let operations: [Operation]

  internal init(conditionTraits: [ConditionTrait] = [], operations: [Operation] = []) {
      self.conditionTraits = conditionTraits
      self.operations = operations
  }

  public func prepare(for test: Test) async throws {
      _ = try await evaluate()
  }

  @_spi(Experimental)
  public func evaluate() async throws -> Bool {
      switch conditionTraits.count {
      case 0:
          preconditionFailure("GroupedConditionTrait must have at least one condition trait.")
      case 1:
          return try await conditionTraits.first!.evaluate()
      default:
          return try await evaluateGroupedConditions()
      }
  }

  private func evaluateGroupedConditions() async throws -> Bool {
      var result: Bool?
      var skipInfo: SkipInfo?

      for (index, operation) in operations.enumerated() where index < conditionTraits.count - 1 {
          do {
              let isEnabled = try await operation.operate(
                  conditionTraits[index],
                  conditionTraits[index + 1],
                  includeSkipInfo: true
              )
              result = updateResult(currentResult: result, isEnabled: isEnabled, operation: operation)
          } catch let error as SkipInfo {
              result = updateResult(currentResult: result, isEnabled: false, operation: operation)
              skipInfo = error
          }
      }

      if let skipInfo = skipInfo, !result! {
          throw skipInfo
      }

      return result!
  }

  private func updateResult(currentResult: Bool?, isEnabled: Bool, operation: Operation) -> Bool {
      if let currentResult = currentResult {
          return operation == .and ? currentResult && isEnabled : currentResult || isEnabled
      } else {
          return isEnabled
      }
  }
}

internal extension GroupedConditionTraits {
  enum Operation : Sendable {
    case and
    case or

    @discardableResult
    fileprivate func operate(_ lhs: ConditionTrait, _ rhs: ConditionTrait, includeSkipInfo: Bool = false) async throws -> Bool {
        let (leftResult, rightResult) = try await evaluate(lhs, rhs)

        let isEnabled: Bool
        let skipSide: (comments: [Comment]?, sourceLocation: SourceLocation)

        switch self {
        case .and:
            isEnabled = evaluateAnd(left: lhs, right: rhs, leftResult: leftResult, rightResult: rightResult)
            skipSide = !isEnabled && !rightResult ? (lhs.comments, lhs.sourceLocation) : (rhs.comments, rhs.sourceLocation)
        case .or:
            isEnabled = evaluateOr(left: lhs, right: rhs, leftResult: leftResult, rightResult: rightResult)
            skipSide = !isEnabled ? (lhs.comments, lhs.sourceLocation) : (rhs.comments, rhs.sourceLocation)
        }

        guard isEnabled || !includeSkipInfo else {
            throw SkipInfo(comment: skipSide.comments?.first, sourceContext: SourceContext(backtrace: nil, sourceLocation: skipSide.sourceLocation))
        }
        return isEnabled
    }

    private func evaluate(_ lhs: ConditionTrait, _ rhs: ConditionTrait) async throws -> (Bool, Bool) {
        async let leftEvaluation = lhs.evaluate()
        async let rightEvaluation = rhs.evaluate()
        return (try await leftEvaluation, try await rightEvaluation)
    }

    private func evaluateAnd(left: ConditionTrait, right: ConditionTrait, leftResult: Bool, rightResult: Bool) -> Bool {
        return left.isInverted && right.isInverted ? leftResult || rightResult : leftResult && rightResult
    }

    private func evaluateOr(left: ConditionTrait, right: ConditionTrait, leftResult: Bool, rightResult: Bool) -> Bool {
        return left.isInverted && right.isInverted ? leftResult && rightResult : leftResult || rightResult
    }
  }
}

public extension Trait where Self == GroupedConditionTraits {
  private static func createGroupedTrait(lhs: Self, rhs: ConditionTrait, operation: GroupedConditionTraits.Operation) -> Self {
      Self(conditionTraits: lhs.conditionTraits + [rhs], operations: lhs.operations + [operation])
  }

  private static func createGroupedTrait(lhs: Self, rhs: Self, operation: GroupedConditionTraits.Operation) -> Self {
      Self(conditionTraits: lhs.conditionTraits + rhs.conditionTraits, operations: lhs.operations + [operation] + rhs.operations)
  }

  static func && (lhs: Self, rhs: ConditionTrait) -> Self {
      createGroupedTrait(lhs: lhs, rhs: rhs, operation: .and)
  }

  static func && (lhs: Self, rhs: Self) -> Self {
      createGroupedTrait(lhs: lhs, rhs: rhs, operation: .and)
  }

  static func || (lhs: Self, rhs: ConditionTrait) -> Self {
      createGroupedTrait(lhs: lhs, rhs: rhs, operation: .or)
  }

  static func || (lhs: Self, rhs: Self) -> Self {
      createGroupedTrait(lhs: lhs, rhs: rhs, operation: .or)
  }
}

