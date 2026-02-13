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

/// A stub test suite.
@Suite
private struct DemoTestSuite {}

@Suite("Test.Trait Tests")
struct Test_TraitTests {
  @Test("Setting traits on a suite filters out non-suite traits", .tags(.traitRelated))
  func filterTraitsOnSuites() async throws {
    let mixedTraits: [any Trait] = [SuiteOnlyTrait(), TestOnlyTrait(), TestAndSuiteTrait()]
    var suite = try #require(await test(for: DemoTestSuite.self))

    // Setting the traits property should filter out non-suite traits
    suite.traits = mixedTraits
    #expect(suite.traits.count == 2)
    #expect(suite.traits[0] is SuiteOnlyTrait)
    #expect(suite.traits[1] is TestAndSuiteTrait)
  }

  @Test("Setting traits on a test filters out non-test traits", .tags(.traitRelated))
  func filterTraitsOnTests() async throws {
    let mixedTraits: [any Trait] = [SuiteOnlyTrait(), TestOnlyTrait(), TestAndSuiteTrait()]
    var test = Test {}

    // Setting the traits property should filter out non-test traits
    test.traits = mixedTraits
    #expect(test.traits.count == 2)
    #expect(test.traits[0] is TestOnlyTrait)
    #expect(test.traits[1] is TestAndSuiteTrait)
  }

}
