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

@Suite("EnvironmentTrait tests", .tags(.traitRelated))
struct EnvironmentTraitTests {
  @Test(
    "Single variable set",
    .environment("SWT_TEST_SINGLE_VAR", "hello_world")
  )
  func singleVariableSet() throws {
    #expect(Environment.variable(named: "SWT_TEST_SINGLE_VAR") == "hello_world")
  }

  @Test(
    "Multiple variables set",
    .environment(["SWT_TEST_VAR_A": "alpha", "SWT_TEST_VAR_B": "beta"])
  )
  func multipleVariablesSet() throws {
    #expect(Environment.variable(named: "SWT_TEST_VAR_A") == "alpha")
    #expect(Environment.variable(named: "SWT_TEST_VAR_B") == "beta")
  }

  @Test(
    "Unset variable",
    .environment(["SWT_TEST_UNSET_VAR": nil])
  )
  func unsetVariable() throws {
    #expect(Environment.variable(named: "SWT_TEST_UNSET_VAR") == nil)
  }

  @Suite("Suite inheritance", .environment(["SWT_TEST_SUITE_VAR": "inherited_value"]))
  struct SuiteInheritance {
    @Test("Inherits from suite")
    func inheritsFromSuite() {
      #expect(Environment.variable(named: "SWT_TEST_SUITE_VAR") == "inherited_value")
    }

    @Test(
      "Overrides suite variable",
      .environment("SWT_TEST_SUITE_VAR", "overridden_value")
    )
    func overridesSuiteVariable() {
      #expect(Environment.variable(named: "SWT_TEST_SUITE_VAR") == "overridden_value")
    }
  }

#if !hasFeature(Embedded)
  @Test("reduce(into:) combines overlapping environment variables")
  func reduceInto() {
    let parent = EnvironmentTrait(variables: ["KEY_A": "original", "KEY_B": "keep"])
    let child = EnvironmentTrait(variables: ["KEY_A": "override", "KEY_C": "new"])
    let reduced = child.reduce(into: parent)

    #expect(reduced?.variables["KEY_A"] == "override")
    #expect(reduced?.variables["KEY_B"] == "keep")
    #expect(reduced?.variables["KEY_C"] == "new")
  }
#endif

  @Test("Environment restoration after test execution")
  func environmentRestoration() async throws {
    let key = "SWT_TEST_RESTORATION_KEY"
    let originalValue = "original_state"
    Environment.setVariable(originalValue, named: key)
    defer {
      Environment.setVariable(nil, named: key)
    }

    let trait = EnvironmentTrait(variables: [key: "temporary_state"])
    let test = Test(name: "dummy") {}

    try await trait.provideScope(for: test, testCase: nil) {
      #expect(Environment.variable(named: key) == "temporary_state")
    }

    #expect(Environment.variable(named: key) == originalValue)
  }

  @Test("Environment restoration on thrown error")
  func environmentRestorationOnError() async throws {
    let key = "SWT_TEST_THROW_KEY"
    Environment.setVariable(nil, named: key)

    struct DummyError: Error {}
    let trait = EnvironmentTrait(variables: [key: "temporary_value"])
    let test = Test(name: "dummy") {}

    do {
      try await trait.provideScope(for: test, testCase: nil) {
        #expect(Environment.variable(named: key) == "temporary_value")
        throw DummyError()
      }
    } catch is DummyError {
      // Expected error
    }

    #expect(Environment.variable(named: key) == nil)
  }
}
