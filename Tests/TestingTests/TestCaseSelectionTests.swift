//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalTestRunning) @_spi(ExperimentalParameterizedTesting) @_spi(ExperimentalEventHandling) import Testing

@Suite("Test.Case Selection Tests")
struct TestCaseSelectionTests {
  @Test("Multiple arguments passed to one parameter, selecting one case")
  func oneParameterSelectingOneCase() async {
    let fixtureTest = Test(arguments: ["a", "b"], parameters: [Test.ParameterInfo(index: 0, firstName: "value")]) { value in
      #expect(value == "a")
    }

    var configuration = Configuration()
    configuration.testCaseFilter = { test in
      guard test == fixtureTest else { return nil }
      return { testCase, _ in
        testCase.id == Test.Case.ID(argumentIDs: ["a"])
      }
    }

    await confirmation { testStarted in
      configuration.eventHandler = { event, context in
        if case .testCaseStarted = event.kind {
          testStarted()
        }
        if case let .issueRecorded(issue) = event.kind {
          Issue.record("Unexpected issue: \(issue)")
        }
      }

      await fixtureTest.run(configuration: configuration)
    }
  }

  @Test("Multiple arguments passed to one parameter, selecting a subset of cases")
  func oneParameterSelectingMultipleCases() async {
    let fixtureTest = Test(arguments: ["a", "b", "c"], parameters: [Test.ParameterInfo(index: 0, firstName: "value")]) { value in
      #expect(value != "b")
    }

    var configuration = Configuration()
    configuration.testCaseFilter = { test in
      guard test == fixtureTest else { return nil }
      return { testCase, _ in
        Set<Test.Case.ID>([
          Test.Case.ID(argumentIDs: ["a"]),
          Test.Case.ID(argumentIDs: ["c"]),
        ]).contains(testCase.id)
      }
    }

    await confirmation(expectedCount: 2) { testStarted in
      configuration.eventHandler = { event, context in
        if case .testCaseStarted = event.kind {
          testStarted()
        }
        if case let .issueRecorded(issue) = event.kind {
          Issue.record("Unexpected issue: \(issue)")
        }
      }

      let runner = await Runner(testing: [fixtureTest], configuration: configuration)
      await runner.run()
    }
  }

  @Test("Two collections, each with multiple arguments, passed to two parameters, selecting one case")
  func twoParametersSelectingOneCase() async {
    let fixtureTest = Test(
      arguments: ["a", "b"], [1, 2],
      parameters: [
        Test.ParameterInfo(index: 0, firstName: "stringValue"),
        Test.ParameterInfo(index: 1, firstName: "intValue"),
      ]
    ) { stringValue, intValue in
      #expect(stringValue == "b" && intValue == 2)
    }

    var configuration = Configuration()
    configuration.testCaseFilter = { test in
      guard test == fixtureTest else { return nil }
      return { testCase, _ in
        testCase.id == Test.Case.ID(argumentIDs: ["b", "2"])
      }
    }

    await confirmation { testStarted in
      configuration.eventHandler = { event, context in
        if case .testCaseStarted = event.kind {
          testStarted()
        }
        if case let .issueRecorded(issue) = event.kind {
          Issue.record("Unexpected issue: \(issue)")
        }
      }

      await fixtureTest.run(configuration: configuration)
    }
  }

  @Test("Multiple arguments conforming to CustomTestArgument, passed to one parameter, selecting one case")
  func oneParameterAcceptingCustomTestArgumentSelectingOneCase() async {
    let fixtureTest = Test(arguments: [
      MyCustomTestArgument(id: "a"),
      MyCustomTestArgument(id: "b"),
    ], parameters: [Test.ParameterInfo(index: 0, firstName: "value")]) { arg in
      #expect(arg.id == "a")
    }

    var configuration = Configuration()
    configuration.testCaseFilter = { test in
      guard test == fixtureTest else { return nil }
      return { testCase, _ in
        testCase.id == Test.Case.ID(argumentIDs: ["a"])
      }
    }

    await confirmation { testStarted in
      configuration.eventHandler = { event, context in
        if case .testCaseStarted = event.kind {
          testStarted()
        }
        if case let .issueRecorded(issue) = event.kind {
          Issue.record("Unexpected issue: \(issue)")
        }
      }

      await fixtureTest.run(configuration: configuration)
    }
  }

  @Test("Multiple arguments conforming to Identifiable, passed to one parameter, selecting one case")
  func oneParameterAcceptingIdentifiableArgumentSelectingOneCase() async {
    let fixtureTest = Test(arguments: [
      MyCustomIdentifiableArgument(id: "a"),
      MyCustomIdentifiableArgument(id: "b"),
    ], parameters: [Test.ParameterInfo(index: 0, firstName: "value")]) { arg in
      #expect(arg.id == "a")
    }

    var configuration = Configuration()
    configuration.testCaseFilter = { test in
      guard test == fixtureTest else { return nil }
      return { testCase, _ in
        testCase.id == Test.Case.ID(argumentIDs: ["a"])
      }
    }

    await confirmation { testStarted in
      configuration.eventHandler = { event, context in
        if case .testCaseStarted = event.kind {
          testStarted()
        }
        if case let .issueRecorded(issue) = event.kind {
          Issue.record("Unexpected issue: \(issue)")
        }
      }

      await fixtureTest.run(configuration: configuration)
    }
  }
}

// MARK: - Fixture argument types

private struct MyCustomTestArgument: CustomTestArgument, CustomStringConvertible {
  var id: String

  func argumentID(in _: Test.Case.Argument.Context) -> String {
    id
  }

  var description: String {
    fatalError("Should not be called")
  }
}

private struct MyCustomIdentifiableArgument: Identifiable, CustomStringConvertible {
  var id: String

  var description: String {
    fatalError("Should not be called")
  }
}
