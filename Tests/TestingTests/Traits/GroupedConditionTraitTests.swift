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

@Suite("Grouped Condition Trait Tests", .tags(.traitRelated))
struct GroupedConditionTraitTests {
    
  @Test("evaluate grouped conditions",arguments: [((Conditions.condition1 && Conditions.condition1), true),
                                  (Conditions.condition3 && Conditions.condition1, false),
    (Conditions.condition1 || Conditions.condition3, true),
                                  (Conditions.condition4 || Conditions.condition4, true),
                                  (Conditions.condition2 || Conditions.condition2, false), (Conditions.condition1 && Conditions.condition2 || Conditions.condition3 && Conditions.condition4, false)])
  func evaluateCondition(_ condition: GroupedConditionTrait, _ expected: Bool) async throws {
    let result = try await condition.evaluate()
    #expect( result == expected)
  }
  

  
  @Test("Applying mixed traits", Conditions.condition1 || Conditions.condition3)
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
