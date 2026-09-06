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

  @Test
  func evaluateCondition() async throws {
    let trueUnconditional = ConditionTrait(kind: .unconditional(true), comments: [], sourceLocation: #Testing::sourceLocation)
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

  // MARK: - Async closure overloads

  @Test("evaluate() with async closure (.enabled)")
  func evaluateAsyncEnabledClosure() async throws {
    // The async closure overload of .enabled(_:sourceLocation:_:) had no
    // dedicated test. Verify that it correctly evaluates an async condition.
    let enabledAsync = ConditionTrait.enabled("async enabled") {
      await Task { true }.value
    }
    let disabledAsync = ConditionTrait.enabled("async disabled") {
      await Task { false }.value
    }
    #expect(try await enabledAsync.evaluate())
    #expect(try await !(disabledAsync.evaluate()))
  }

  @Test("evaluate() with async closure (.disabled)")
  func evaluateAsyncDisabledClosure() async throws {
    // The async closure overload of .disabled(_:sourceLocation:_:) had no
    // dedicated test. Verify that it correctly evaluates an async condition
    // and inverts the result (disabled when condition returns true).
    let disabledWhenTrue = ConditionTrait.disabled("async disabled") {
      await Task { true }.value
    }
    let enabledWhenFalse = ConditionTrait.disabled("async enabled") {
      await Task { false }.value
    }
    #expect(try await !(disabledWhenTrue.evaluate()))
    #expect(try await enabledWhenFalse.evaluate())
  }

  // MARK: - Throwing closure

  @Test("evaluate() propagates error thrown by async condition closure")
  func evaluateThrowingClosure() async {
    struct ConditionError: Error {}

    let throwingCondition = ConditionTrait.enabled("throws") {
      throw ConditionError()
    }
    // evaluate() is declared as `throws`, so a thrown error must propagate.
    do {
      _ = try await throwingCondition.evaluate()
      Issue.record("Expected evaluate() to throw ConditionError")
    } catch is ConditionError {
      // Expected — the closure's thrown error propagated correctly.
    } catch {
      Issue.record("Unexpected error type: \(error)")
    }
  }

  // MARK: - isConstant property

  @Test("isConstant is true for unconditional traits (.disabled(), .enabled(if:))")
  func isConstantForUnconditionalTraits() {
    // .disabled() and .enabled(if: Bool) use .unconditional kind, so
    // isConstant must be true.
    #expect(ConditionTrait.disabled().isConstant)
    #expect(ConditionTrait.disabled("with comment").isConstant)
    #expect(ConditionTrait.enabled(if: true).isConstant)
    #expect(ConditionTrait.enabled(if: false).isConstant)
  }

  @Test("isConstant is false for conditional (closure-based) traits")
  func isConstantForConditionalTraits() {
    // .enabled(_:_:) and .disabled(_:_:) with closures use .conditional kind,
    // so isConstant must be false.
    #expect(!ConditionTrait.enabled("async") { true }.isConstant)
    #expect(!ConditionTrait.disabled("async") { false }.isConstant)
  }

  // MARK: - isRecursive property

  @Test("isRecursive is true for ConditionTrait")
  func isRecursiveIsTrue() {
    // ConditionTrait.isRecursive must be true so that a condition applied to a
    // suite is also inherited by all tests inside that suite.
    #expect(ConditionTrait.disabled().isRecursive)
    #expect(ConditionTrait.enabled(if: true).isRecursive)
    #expect(ConditionTrait.enabled("comment") { true }.isRecursive)
  }

  // MARK: - Comments

  @Test("ConditionTrait carries its comment correctly")
  func conditionTraitComments() {
    let trait = ConditionTrait.disabled("reason for skipping")
    #expect(trait.comments == ["reason for skipping"])

    let noComment = ConditionTrait.disabled()
    #expect(noComment.comments.isEmpty)

    let enabledWithComment = ConditionTrait.enabled(if: false, "must be enabled")
    #expect(enabledWithComment.comments == ["must be enabled"])
  }

  // MARK: - Test skipping behaviour (end-to-end)

  @Test("Test is skipped when async .enabled closure returns false")
  func testIsSkippedByAsyncEnabledFalse() async {
    await confirmation("test skipped") { skipped in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case .testSkipped = event.kind {
          skipped()
        }
      }
      await Test(
        .enabled("async disabled") { await Task { false }.value }
      ) {}.run(configuration: configuration)
    }
  }

  @Test("Test is skipped when async .disabled closure returns true")
  func testIsSkippedByAsyncDisabledTrue() async {
    await confirmation("test skipped") { skipped in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case .testSkipped = event.kind {
          skipped()
        }
      }
      await Test(
        .disabled("async disabled") { await Task { true }.value }
      ) {}.run(configuration: configuration)
    }
  }

  @Test("Test is NOT skipped when async .enabled closure returns true")
  func testIsNotSkippedByAsyncEnabledTrue() async {
    await confirmation("test skipped", expectedCount: 0) { skipped in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case .testSkipped = event.kind {
          skipped()
        }
      }
      await Test(
        .enabled("async enabled") { await Task { true }.value }
      ) {}.run(configuration: configuration)
    }
  }

  @Test("Test is NOT skipped when async .disabled closure returns false")
  func testIsNotSkippedByAsyncDisabledFalse() async {
    await confirmation("test skipped", expectedCount: 0) { skipped in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case .testSkipped = event.kind {
          skipped()
        }
      }
      await Test(
        .disabled("async not disabled") { await Task { false }.value }
      ) {}.run(configuration: configuration)
    }
  }
}

