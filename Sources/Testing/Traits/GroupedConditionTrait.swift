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
  
  var conditionTraits: [ConditionTrait]
  var operations: [Operation] = []
  
  public func prepare(for test: Test) async throws {
    let traitCount = conditionTraits.count
    guard traitCount >= 2 else {
      if let firstTrait = conditionTraits.first {
        try await firstTrait.prepare(for: test)
      }
      return
    }
    for (index, operation) in operations.enumerated() where index < traitCount - 1 {
        let trait1 = conditionTraits[index]
        let trait2 = conditionTraits[index + 1]
        try await operation.operate(trait1, trait2, includeSkipInfo: true)
      
    }
  }

  @_spi(Experimental)
  public func evaluate() async throws -> Bool {
    let traitCount = conditionTraits.count
    guard traitCount >= 2 else {
      if let firstTrait = conditionTraits.first {
        return try await firstTrait.evaluate()
      }
      preconditionFailure()
    }
    var result: Bool = true
    for (index, operation) in operations.enumerated() {
        let isEnabled = try await operation.operate(conditionTraits[index],
                                                    conditionTraits[index + 1])
        result = result && isEnabled
    }
    return result
  }
}

extension Trait where Self == GroupedConditionTrait {
  
  static func && (lhs: Self, rhs: ConditionTrait) -> Self {
    Self(conditionTraits: lhs.conditionTraits + [rhs], operations: lhs.operations + [.and])
  }
  
  static func && (lhs: Self, rhs: Self) -> Self {
    Self(conditionTraits: lhs.conditionTraits + rhs.conditionTraits, operations: lhs.operations + [.and] + rhs.operations)
  }
  static func || (lhs: Self, rhs: ConditionTrait) -> Self {
    Self(conditionTraits: lhs.conditionTraits + [rhs], operations: lhs.operations + [.or])
  }
  
  static func || (lhs: Self, rhs: Self) -> Self {
    Self(conditionTraits: lhs.conditionTraits + rhs.conditionTraits, operations: lhs.operations + [.or] + rhs.operations)
  }
}


extension GroupedConditionTrait {
  enum Operation {
    case `and`
    case `or`
    
    @discardableResult
    func operate(_ lhs: ConditionTrait,_ rhs: ConditionTrait, includeSkipInfo: Bool = false) async throws -> Bool {
      let (l,r) = try await evaluate(lhs, rhs)
      
      var skipSide: (comments: [Comment]?, sourceLocation: SourceLocation) = (nil, lhs.sourceLocation)
      let isEnabled: Bool
      switch self {
      case .and:
        isEnabled = l && r
        
        if !isEnabled {
          skipSide = r ? (lhs.comments, lhs.sourceLocation) : (rhs.comments, rhs.sourceLocation)
        }
      case .or:
        isEnabled = ((l != lhs.isInverted) || (r != rhs.isInverted)) != lhs.isInverted && rhs.isInverted
        
        if !isEnabled {
          skipSide = (lhs.comments, lhs.sourceLocation)
        }
      }
      
      guard isEnabled || !includeSkipInfo else {
        let sourceContext = SourceContext(backtrace: nil, sourceLocation: skipSide.sourceLocation)
        throw SkipInfo(comment: skipSide.comments?.first, sourceContext: sourceContext)
      }
      return isEnabled
    }
    
    private func evaluate(_ lhs: ConditionTrait, _ rhs: ConditionTrait) async throws -> (Bool, Bool) {
      let l = try await lhs.evaluate()
      let r = try await rhs.evaluate()
      return (l, r)
    }
  }
}
