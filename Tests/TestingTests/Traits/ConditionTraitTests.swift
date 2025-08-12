//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @testable import Testing

@Suite("Condition Trait Tests", .tags(.traitRelated))
struct ConditionTraitTests {
  @Test(
    ".enabled trait",
    .enabled { true },
    .bug("https://github.com/swiftlang/swift/issues/76409", "Verify the custom trait with closure causes @Test macro to fail is fixed")
  )
  func enabledTraitClosure() throws {}

  @Test(
    ".enabled if trait",
    .enabled(if: true)
  )
  func enabledTraitIf() throws {}

  @Test(
    ".disabled trait",
    .disabled { false },
    .bug("https://github.com/swiftlang/swift/issues/76409", "Verify the custom trait with closure causes @Test macro to fail is fixed")
  )
  func disabledTraitClosure() throws {}

  @Test(
    ".disabled if trait",
    .disabled(if: false)
  )
  func disabledTraitIf() throws {}

  @Test(
    ".enabled if a certain env var exists",
    .enabled(ifEnvironmentPresent: "TEST_ENV_VAR")
  )
  func enabledEnvironmentPresentIf() throws {}

  @Test(
    ".disabled if a certain env var exists",
    .disabled(ifEnvironmentPresent: "TEST_ENV_VAR")
  )
  func disabledEnvironmentPresentIf() throws {}

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

  // TODO: What do we wanna do about envvar thread safety? This won't be safe to
  // run in parallel alongside any other env var based tests because it ends up
  // calling setenv.
  @Test
  func evaluateConditionEnvironmentVariable() async throws {
    let enabledEnvironment = ConditionTrait.enabled(ifEnvironmentPresent: "TEST_ENV_VAR")
    let disabledEnvironment = ConditionTrait.disabled(ifEnvironmentPresent: "TEST_ENV_VAR")
    var result: Bool

    result = try await enabledEnvironment.evaluate()
    #expect(!result)
    result = try await disabledEnvironment.evaluate()
    #expect(result)

    try #require(Environment.setVariable("1", named: "TEST_ENV_VAR"))
    result = try await enabledEnvironment.evaluate()
    #expect(result)
    result = try await disabledEnvironment.evaluate()
    #expect(!result)

    try #require(Environment.setVariable("0", named: "TEST_ENV_VAR"))
    result = try await enabledEnvironment.evaluate()
    #expect(result, "Actual value of the environment variable shouldn't matter")
    result = try await disabledEnvironment.evaluate()
    #expect(!result, "Actual value of the environment variable shouldn't matter")
  }
}
