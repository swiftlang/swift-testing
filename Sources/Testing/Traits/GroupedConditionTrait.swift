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
    let conditionResult = try await evaluate()
  }

  @_spi(Experimental)
  public func evaluate() async throws -> Bool {
    try await conditionClosure()
  }
}

extension Trait where Self == GroupedConditionTrait {
  
  static func && (lhs: Self, rhs: ConditionTrait) -> Self {
    Self(isInverted: lhs.isInverted && rhs.isInverted,
         conditionClosure: {
      let rhsEvaluation = try await rhs.evaluate()
      let lhsEvaluation = try await lhs.evaluate()
      let isEnabled = if (lhs.isInverted && rhs.isInverted) {
        lhsEvaluation || rhsEvaluation
      } else {
        lhsEvaluation && rhsEvaluation
      }
      
      guard isEnabled else {
        let sourceContext = SourceContext(backtrace: nil, sourceLocation: rhs.sourceLocation)
        let error = SkipInfo(sourceContext: sourceContext)
        throw error
      }
      return isEnabled
    })
  }
  
  static func && (lhs: Self, rhs: Self) -> Self {
    Self(isInverted: lhs.isInverted && rhs.isInverted,
         conditionClosure: {
      let rhsEvaluation = try await rhs.evaluate()
      let lhsEvaluation = try await lhs.evaluate()
      let isEnabled = if (lhs.isInverted && rhs.isInverted) {
        lhsEvaluation || rhsEvaluation
      } else {
        lhsEvaluation && rhsEvaluation
      }
      
      guard isEnabled else {
        preconditionFailure("the step should've detected erailer that it was disabled")
      }
      return isEnabled
    })
  }
  static func || (lhs: Self, rhs: ConditionTrait) -> Self {
    Self(isInverted: lhs.isInverted && rhs.isInverted,
         conditionClosure: {
      let rhsEvaluation = try await rhs.evaluate()
      let lhsEvaluation = try await lhs.evaluate()
      let isEnabled = if (lhs.isInverted && rhs.isInverted) {
        lhsEvaluation && rhsEvaluation
      } else {
        lhsEvaluation || rhsEvaluation
      }
      
      guard isEnabled else {
        let sourceContext = SourceContext(backtrace: nil, sourceLocation: rhs.sourceLocation)
        let error = SkipInfo(sourceContext: sourceContext)
        throw error
      }
      return isEnabled
    })
  }
  
  static func || (lhs: Self, rhs: Self) -> Self {
    Self(isInverted: lhs.isInverted && rhs.isInverted,
         conditionClosure: {
      let rhsEvaluation = try await rhs.evaluate()
      let lhsEvaluation = try await lhs.evaluate()
      let isEnabled = if (lhs.isInverted && rhs.isInverted) {
        lhsEvaluation && rhsEvaluation
      } else {
        lhsEvaluation || rhsEvaluation
      }
      
      guard isEnabled else {
        preconditionFailure("the step should've detected erailer that it was disabled")
      }
      return isEnabled
    })
  }
}
