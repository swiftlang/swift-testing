//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
    
@testable @_spi(ForToolsIntegrationOnly) import Testing

@Suite("Runner.Plan Tests")
struct PlanTests {
  @Test("Unfiltered tests")
  func unfilteredTests() async throws {
    var configuration = Configuration()
    configuration.testFilter = .unfiltered

    let plan = await Runner.Plan(tests: Test.all, configuration: configuration)
    #expect(plan.steps.count > 0)
  }

  @Test("Selected tests by ID")
  func selectedTests() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
    ]

    let selection = [innerTestType.id]
    var configuration = Configuration()
    configuration.setTestFilter(toInclude: selection, includeHiddenTests: true)

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    #expect(plan.steps.contains(where: { $0.test == outerTestType }))
    #expect(!plan.steps.contains(where: { $0.test == testA }))
    #expect(plan.steps.contains(where: { $0.test == innerTestType }))
    #expect(plan.steps.contains(where: { $0.test == testB }))
  }

  @Test("Multiple selected tests by ID")
  func multipleSelectedTests() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
    ]

    var configuration = Configuration()
    let selection = [innerTestType.id, outerTestType.id]
    configuration.setTestFilter(toInclude: selection, includeHiddenTests: true)

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(planTests.contains(testA))
    #expect(planTests.contains(innerTestType))
    #expect(planTests.contains(testB))
  }

  @Test("Excluded tests by ID")
  func excludedTests() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
    ]

    var testFilter = Configuration.TestFilter(excluding: [innerTestType.id])
    testFilter.includeHiddenTests = true
    var configuration = Configuration()
    configuration.testFilter = testFilter

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(planTests.contains(testA))
    #expect(!planTests.contains(innerTestType))
    #expect(!planTests.contains(testB))
  }

  @Test("Selected tests by any tag")
  func selectedTestsByAnyTag() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))
    let testC = try #require(await testFunction(named: "otherSucceeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
      testC,
    ]

    var configuration = Configuration()
    var filter = Configuration.TestFilter(includingAnyOf: [.namedConstant, .anotherConstant])
    filter.includeHiddenTests = true
    configuration.testFilter = filter

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(!planTests.contains(testA))
    #expect(planTests.contains(innerTestType))
    #expect(planTests.contains(testB))
    #expect(planTests.contains(testC))
  }

  @Test("Selected tests by all tags")
  func selectedTestsByAllTags() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))
    let testC = try #require(await testFunction(named: "otherSucceeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
      testC,
    ]

    var configuration = Configuration()
    var filter = Configuration.TestFilter(includingAllOf: [.namedConstant, .anotherConstant])
    filter.includeHiddenTests = true
    configuration.testFilter = filter

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(!planTests.contains(testA))
    #expect(planTests.contains(innerTestType))
    #expect(planTests.contains(testB))
    #expect(!planTests.contains(testC))
  }

  @Test("Excluded tests by any tag")
  func excludedTestsByAnyTag() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))
    let testC = try #require(await testFunction(named: "otherSucceeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
      testC,
    ]

    var configuration = Configuration()
    var filter = Configuration.TestFilter(excludingAnyOf: [.namedConstant, .anotherConstant])
    filter.includeHiddenTests = true
    configuration.testFilter = filter

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(planTests.contains(testA))
    #expect(!planTests.contains(innerTestType))
    #expect(!planTests.contains(testB))
    #expect(!planTests.contains(testC))
  }

  @Test("Excluded tests by all tags")
  func excludedTestsByAllTags() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))
    let testC = try #require(await testFunction(named: "otherSucceeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
      testC,
    ]

    var configuration = Configuration()
    var filter = Configuration.TestFilter(excludingAllOf: [.namedConstant, .anotherConstant])
    filter.includeHiddenTests = true
    configuration.testFilter = filter

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(planTests.contains(testA))
    #expect(planTests.contains(innerTestType))
    #expect(!planTests.contains(testB))
    #expect(planTests.contains(testC))
  }

  @Test("Mixed included and excluded tests by ID")
  func mixedIncludedAndExcludedTests() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))
    let testC = try #require(await testFunction(named: "otherSucceeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
      testC,
    ]

    var configuration = Configuration()
    var filter = Configuration.TestFilter(including: [testA.id, innerTestType.id])
    filter.includeHiddenTests = true
    filter.combine(with: Configuration.TestFilter(excluding: [testC.id]))
    configuration.testFilter = filter

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(planTests.contains(testA))
    #expect(planTests.contains(innerTestType))
    #expect(planTests.contains(testB))
    #expect(!planTests.contains(testC))
  }

  @Test("Combining test filter by ID with .unfiltered (rhs)")
  func combiningTestFilterWithUnfilteredRHS() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
    ]

    var configuration = Configuration()
    let selection = [innerTestType.id, outerTestType.id]
    var testFilter = Configuration.TestFilter(including: selection)
    testFilter.combine(with: .unfiltered)
    testFilter.includeHiddenTests = true
    configuration.testFilter = testFilter

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(planTests.contains(testA))
    #expect(planTests.contains(innerTestType))
    #expect(planTests.contains(testB))
  }

  @Test("Combining test filter by ID with .unfiltered (lhs)")
  func combiningTestFilterWithUnfilteredLHS() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
    ]

    var configuration = Configuration()
    let selection = [innerTestType.id, outerTestType.id]
    var testFilter = Configuration.TestFilter.unfiltered
    testFilter.combine(with: Configuration.TestFilter(including: selection))
    testFilter.includeHiddenTests = true
    configuration.testFilter = testFilter

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(planTests.contains(testA))
    #expect(planTests.contains(innerTestType))
    #expect(planTests.contains(testB))
  }

  @Test("Combining test filter by ID with by tag")
  func combiningTestFilterByIDAndByTag() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
    ]

    var configuration = Configuration()
    let selection = [innerTestType.id, outerTestType.id]
    var testFilter = Configuration.TestFilter(including: selection)
    testFilter.combine(with: .init(excludingAnyOf: [Tag("A")]))
    testFilter.includeHiddenTests = true
    configuration.testFilter = testFilter

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(planTests.contains(testA))
    #expect(planTests.contains(innerTestType))
    #expect(planTests.contains(testB))
  }

  @Test("Combining test filters with .or")
  func combiningTestFilterWithOr() async throws {
    let outerTestType = try #require(await test(for: SendableTests.self))
    let testA = try #require(await testFunction(named: "succeeds()", in: SendableTests.self))
    let innerTestType = try #require(await test(for: SendableTests.NestedSendableTests.self))
    let testB = try #require(await testFunction(named: "succeeds()", in: SendableTests.NestedSendableTests.self))
    let testC = try #require(await testFunction(named: "otherSucceeds()", in: SendableTests.NestedSendableTests.self))

    let tests = [
      outerTestType,
      testA,
      innerTestType,
      testB,
      testC
    ]

    var configuration = Configuration()
    let selection = [testA.id]
    var testFilter = Configuration.TestFilter(including: selection)
    testFilter.combine(with: .init(includingAnyOf: [.anotherConstant]), using: .or)
    testFilter.includeHiddenTests = true
    configuration.testFilter = testFilter

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(planTests.contains(testA))
    #expect(planTests.contains(innerTestType))
    #expect(planTests.contains(testB))
    #expect(!planTests.contains(testC))
  }

  @Test("Recursive trait application")
  func recursiveTraitApplication() async throws {
    let outerTestType = try #require(await test(for: OuterTest.self))
    // Intentionally omitting intermediate tests here...
    let deeplyNestedTest = try #require(await testFunction(named: "example()", in: OuterTest.IntermediateType.InnerTest.self))

    let tests = [outerTestType, deeplyNestedTest]

    var configuration = Configuration()
    let selection = [outerTestType.id, deeplyNestedTest.id]
    configuration.setTestFilter(toInclude: selection, includeHiddenTests: true)

    let plan = await Runner.Plan(tests: tests, configuration: configuration)

    let testWithTraitAdded = try #require(plan.steps.map(\.test).first { $0.name == "example()" })
    #expect(testWithTraitAdded.traits.contains { $0 is DummyRecursiveTrait })
  }

  @Test("Relative order of recursively applied traits")
  func recursiveTraitOrder() async throws {
    let testSuiteA = try #require(await test(for: RelativeTraitOrderingTests.A.self))
    let testSuiteB = try #require(await test(for: RelativeTraitOrderingTests.A.B.self))
    let testSuiteC = try #require(await test(for: RelativeTraitOrderingTests.A.B.C.self))
    let testFuncX = try #require(await testFunction(named: "x()", in: RelativeTraitOrderingTests.A.B.C.self))

    let tests = [testSuiteA, testSuiteB, testSuiteC, testFuncX]

    var configuration = Configuration()
    let selection = [testSuiteA.id]
    configuration.setTestFilter(toInclude: selection, includeHiddenTests: true)

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let testFuncXWithTraits = try #require(plan.steps.map(\.test).first { $0.name == "x()" })

    let traitDescriptions = Array(testFuncXWithTraits.traits.lazy
      .compactMap { $0 as? BasicRecursiveTrait }
      .map(\.description))
    #expect(traitDescriptions == ["A", "B", "C", "x"])
  }

  @Test("Static functions are nested at the same level as instance functions")
  func staticFunctionIsNestedAtSameLevelAsInstanceFunction() async throws {
    let plan = await Runner.Plan(selecting: SendableTests.self)
    // The tests themselves are nested deeper, under the source location, so
    // we're just checking here that the key path has been constructed correctly
    // up to the function names.
    let typeInfo = TypeInfo(describing: SendableTests.self)
    #expect(plan.stepGraph.subgraph(at: typeInfo.fullyQualifiedNameComponents + CollectionOfOne("succeeds()")) != nil)
    #expect(plan.stepGraph.subgraph(at: typeInfo.fullyQualifiedNameComponents + CollectionOfOne("static()")) != nil)
    #expect(plan.stepGraph.subgraph(at: typeInfo.fullyQualifiedNameComponents + CollectionOfOne("reserved1(reserved2:)")) != nil)
  }

#if !SWT_NO_SNAPSHOT_TYPES
  @Test("Test cases of a disabled test are not evaluated")
  func disabledTestCases() async throws {
    var configuration = Configuration()
    configuration.setEventHandler { event, context in
      guard case .testSkipped = event.kind else {
        return
      }
      let testSnapshot = try #require(context.test.map { Test.Snapshot(snapshotting: $0) })
      #expect(testSnapshot.testCases?.isEmpty ?? false)
    }

    await runTestFunction(named: "disabled(x:)", in: ParameterizedTests.self, configuration: configuration)
  }
#endif
}

// MARK: - Fixtures

@Suite(.hidden, DummyRecursiveTrait())
private struct OuterTest {
  struct IntermediateType {
    @Suite(.hidden)
    struct InnerTest {
      @Test(.hidden) func example() {}
    }
  }
}

private struct DummyRecursiveTrait: TestTrait, SuiteTrait {
  var isRecursive: Bool {
    true
  }
}

@Suite(.hidden)
struct RelativeTraitOrderingTests {
  @Suite(.hidden, BasicRecursiveTrait("A"))
  struct A {
    @Suite(.hidden, BasicRecursiveTrait("B"))
    struct B {
      @Suite(.hidden, BasicRecursiveTrait("C"))
      struct C {
        @Test(.hidden, BasicRecursiveTrait("x"))
        func x() {}
      }
    }
  }
}

private struct BasicRecursiveTrait: SuiteTrait, TestTrait, CustomStringConvertible {
  var isRecursive: Bool { true }
  var description: String
  init(_ description: String) {
    self.description = description
  }
}
