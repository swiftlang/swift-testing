//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) import Testing

@Suite("Condition Trait Tests", .tags(.traitRelated))
struct ConditionTraitTests {
  #if compiler(>=6.1)
  @Test(
    ".enabled trait",
    .enabled { true },
    .bug("https://github.com/swiftlang/swift/issues/76409", "Verify the custom trait with closure causes @Test macro to fail is fixed")
  )
  func enabledTraitClosure() throws {}
  #endif

  @Test(
    ".enabled if trait",
    .enabled(if: true)
  )
  func enabledTraitIf() throws {}

  #if compiler(>=6.1)
  @Test(
    ".disabled trait",
    .disabled { false },
    .bug("https://github.com/swiftlang/swift/issues/76409", "Verify the custom trait with closure causes @Test macro to fail is fixed")
  )
  func disabledTraitClosure() throws {}
  #endif

  @Test(
    ".disabled if trait",
    .disabled(if: false)
  )
  func disabledTraitIf() throws {}
  
  @Test
  func evaluateCondition() async throws {
    let trueUnconditional = ConditionTrait(kind: .unconditional(true), comments: [], sourceLocation: #_sourceLocation)
    let falseUnconditional = ConditionTrait.disabled()
    let enabledTrue = ConditionTrait.enabled(if: true)
    let enabledFalse = ConditionTrait.enabled(if: false)
    var result: Bool
    
    result = try await trueUnconditional.evaluate()
    #expect(result)
    result = try await falseUnconditional.evaluate()
    #expect(!result)
    result = try await enabledTrue.evaluate()
    #expect(result)
    result = try await enabledFalse.evaluate()
    #expect(!result)
  }
  
  @Test("AND operator", arguments: [((Conditions.condition1 && Conditions.condition1), true),
  (Conditions.condition1 && Conditions.condition3, false)])
  func ANDOperator(_ condition: GroupedConditionTrait, _ expected: Bool) async throws {
    #expect(try await condition.evaluate() == expected)
  }
    
  
  @Test("OR operator",arguments: [(Conditions.condition1 || Conditions.condition3, true),
                                  (Conditions.condition4 || Conditions.condition4, true),
                                  (Conditions.condition2 || Conditions.condition2, false),])
  func OROperator(_ condition: GroupedConditionTrait, _ expected: Bool) async throws {
    print(condition)
    let result = try await condition.evaluate()
    #expect( result == expected)
  }
  
  @Test("Mix Operator Logic on Condition Traits", arguments: [(Conditions.condition1 && Conditions.condition2 || Conditions.condition3 && Conditions.condition4, false)])
  func MixOperator(_ condition: GroupedConditionTrait, _ expected: Bool) async throws {
    let result = try await condition.evaluate()
    #expect( result == expected)
  }
  
  @Test("Applying mixed traits", Conditions.condition2 || Conditions.condition2)
  func applyMixedTraits() {
    #expect(true)
  }
  
  private enum Conditions {
    static let condition1 = ConditionTrait.enabled(if: true, "Some comment for condition1")
    static let condition2 = ConditionTrait.enabled(if: false, "Some comment for condition2")
    static let condition3 = ConditionTrait.disabled(if: true, "Some comment for condition3")
    static let condition4 = ConditionTrait.disabled(if: false, "Some comment for condition4")
  }
}
