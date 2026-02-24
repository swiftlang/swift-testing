//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) import Testing

@Suite("Test.ID Tests")
struct Test_IDTests {
  @Test func topmostSuiteInCurrentModule() async throws {
    let plan = await Runner.Plan(selecting: SomeSuite.self)

    let suiteID = try #require(plan.tests.first { $0.name == "SomeSuite" }?.id)
    #expect(suiteID.moduleName == .currentModuleName())

    let functionID = try #require(plan.tests.first { $0.name == "example()" }?.id)
    #expect(functionID.moduleName == .currentModuleName())
  }

  @Test func topmostSuiteInDifferentModule() async throws {
    let plan = await Runner.Plan(selecting: String.AnotherSuite.self)

    let suiteID = try #require(plan.tests.first { $0.name == "AnotherSuite" }?.id)
    #expect(suiteID.moduleName == .currentModuleName())

    let functionID = try #require(plan.tests.first { $0.name == "example()" }?.id)
    #expect(functionID.moduleName == .currentModuleName())
  }
}

// MARK: - Fixtures

@Suite(.hidden) struct SomeSuite {
  @Test func example() {}
}

extension String {
  @Suite(.hidden) struct AnotherSuite {
    @Test func example() {}
  }
}
