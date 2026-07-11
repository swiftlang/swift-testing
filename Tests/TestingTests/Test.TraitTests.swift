//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

/// A trait that only applies to suites
private struct SuiteOnlyTrait: SuiteTrait {}

/// A trait that only applies to test functions
private struct TestOnlyTrait: TestTrait {}

/// A trait that applies to both
private struct TestAndSuiteTrait: SuiteTrait, TestTrait {}

@Suite
struct `Test.Trait Tests` {
  @Test(.tags(.traitRelated))
  func `Setting traits on a suite filters out non-suite traits`() async throws {
    let mixedTraits: [any Trait] = [SuiteOnlyTrait(), TestOnlyTrait(), TestAndSuiteTrait()]
    var suite = Test(
      displayName: "Fake Suite",
      traits: [],
      sourceLocation: #_sourceLocation,
      containingTypeInfo: TypeInfo(describing: Void.self),
    )

    // Setting the traits property should filter out non-suite traits
    suite.traits = mixedTraits
    #expect(suite.traits.count == 2)
    #expect(suite.traits[0] is SuiteOnlyTrait)
    #expect(suite.traits[1] is TestAndSuiteTrait)
  }

  @Test(.tags(.traitRelated))
  func `Setting traits on a test filters out non-test traits`() async throws {
    let mixedTraits: [any Trait] = [SuiteOnlyTrait(), TestOnlyTrait(), TestAndSuiteTrait()]
    var test = Test {}

    // Setting the traits property should filter out non-test traits
    test.traits = mixedTraits
    #expect(test.traits.count == 2)
    #expect(test.traits[0] is TestOnlyTrait)
    #expect(test.traits[1] is TestAndSuiteTrait)
  }

}
