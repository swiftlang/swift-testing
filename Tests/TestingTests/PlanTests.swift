//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
    
@testable @_spi(ExperimentalTestRunning) import Testing

@Suite("Runner.Plan Tests")
struct PlanTests {
  @Test("Selected tests")
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

    let selection = Test.ID.Selection(testIDs: [innerTestType.id])
    var configuration = Configuration()
    configuration.uncheckedTestFilter = makeTestFilter(matching: selection, includeHiddenTests: true)

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    #expect(plan.steps.contains(where: { $0.test == outerTestType }))
    #expect(!plan.steps.contains(where: { $0.test == testA }))
    #expect(plan.steps.contains(where: { $0.test == innerTestType }))
    #expect(plan.steps.contains(where: { $0.test == testB }))
  }

  @Test("Multiple selected tests")
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
    let selection = Test.ID.Selection(testIDs: [innerTestType.id, outerTestType.id])
    configuration.uncheckedTestFilter = makeTestFilter(matching: selection, includeHiddenTests: true)

    let plan = await Runner.Plan(tests: tests, configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(outerTestType))
    #expect(planTests.contains(testA))
    #expect(planTests.contains(innerTestType))
    #expect(planTests.contains(testB))
  }

  @Test("Recursive trait application")
  func recursiveTraitApplication() async throws {
    let outerTestType = try #require(await test(for: OuterTest.self))
    // Intentionally omitting intermediate tests here...
    let deeplyNestedTest = try #require(await testFunction(named: "example()", in: OuterTest.IntermediateType.InnerTest.self))

    let tests = [outerTestType, deeplyNestedTest]

    var configuration = Configuration()
    let selection = Test.ID.Selection(testIDs: [outerTestType.id, deeplyNestedTest.id])
    configuration.uncheckedTestFilter = makeTestFilter(matching: selection, includeHiddenTests: true)

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
    let selection = Test.ID.Selection(testIDs: [testSuiteA.id])
    configuration.uncheckedTestFilter = makeTestFilter(matching: selection, includeHiddenTests: true)

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
    #expect(plan.stepGraph.subgraph(at: nameComponents(of: SendableTests.self) + CollectionOfOne("succeeds()")) != nil)
    #expect(plan.stepGraph.subgraph(at: nameComponents(of: SendableTests.self) + CollectionOfOne("static()")) != nil)
    #expect(plan.stepGraph.subgraph(at: nameComponents(of: SendableTests.self) + CollectionOfOne("reserved1(reserved2:)")) != nil)
  }

  @Test("Runner.Plan.independentlyRunnableSteps property")
  func independentlyRunnableTests() async throws {
    let plan = await Runner.Plan(selecting: IndependentlyRunnableTests.self)
    #expect(plan.independentlyRunnableSteps.count == 2)
  }
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

struct IndependentlyRunnableTests {
  struct A {
    @Suite(.hidden) struct B {
      @Test(.hidden) func c() {}
      struct D {
        @Test(.hidden) func e() {}
      }
    }
    @Suite(.hidden) struct F {
      @Test(.hidden) func g() {}
    }
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
