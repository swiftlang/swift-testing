//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//


public struct GroupedConditionTrait: TestTrait, SuiteTrait {
  
  let isInverted: Bool

  let conditionClosure: @Sendable () async throws -> Bool
  
  
  
  public func prepare(for test: Test) async throws {
    _ = try await evaluate()
  }

  @_spi(Experimental)
  public func evaluate() async throws -> Bool {
    try await conditionClosure()
  }
}


extension Trait where Self == GroupedConditionTrait {
  static func &&(lhs: Self, rhs: Self) -> Self {
    .combine(lhs: lhs, rhs: rhs, op: .and) { _, _ in
      preconditionFailure("the step should've detected earlier that it was disabled")
    }
  }

  static func &&(lhs: Self, rhs: ConditionTrait) -> Self {
    .combine(lhs: lhs, rhs: .init(isInverted: rhs.isInverted, conditionClosure: rhs.evaluate),
             op: .and) { _, _ in
      let sourceContext = SourceContext(backtrace: nil,
                                        sourceLocation: rhs.sourceLocation)
      throw SkipInfo(sourceContext: sourceContext)
    }
  }

  static func ||(lhs: Self, rhs: Self) -> Self {
    .combine(lhs: lhs, rhs: rhs, op: .or) { _, _ in
      preconditionFailure("the step should've detected earlier that it was disabled")
    }
  }

  static func ||(lhs: Self, rhs: ConditionTrait) -> Self {
    .combine(lhs: lhs, rhs: .init(isInverted: rhs.isInverted, conditionClosure: rhs.evaluate),
             op: .or) { _, _ in
      let sourceContext = SourceContext(backtrace: nil,
                                        sourceLocation: rhs.sourceLocation)
      throw SkipInfo(sourceContext: sourceContext)
    }
  }
}


internal extension GroupedConditionTrait {
  enum Operation { case and, or }

  static func combine(
    lhs: GroupedConditionTrait,
    rhs: GroupedConditionTrait,
    op: Operation,
    onFailure: @Sendable @escaping (_ lhs: Bool, _ rhs: Bool) throws -> Void
  ) -> GroupedConditionTrait {
    GroupedConditionTrait(
      isInverted: lhs.isInverted && rhs.isInverted,
      conditionClosure: {
        let lhsEvaluated = try await lhs.evaluate()
        let rhsEvaluated = try await rhs.evaluate()
        
        let isEnabled: Bool
        switch op {
        case .and:
          isEnabled = (lhs.isInverted && rhs.isInverted)
            ? (lhsEvaluated || rhsEvaluated)
            : (lhsEvaluated && rhsEvaluated)
        case .or:
          isEnabled = (lhs.isInverted && rhs.isInverted)
            ? (lhsEvaluated && rhsEvaluated)
            : (lhsEvaluated || rhsEvaluated)
        }

        guard isEnabled else {
          try onFailure(lhsEvaluated, rhsEvaluated)
          preconditionFailure("Unreachable: failure handler didn't throw")
        }
        return isEnabled
      }
    )
  }
}

