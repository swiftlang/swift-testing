//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
private import TestingInternals

private func configurationForSwiftPMEntryPoint(withArguments args: [String]) throws -> Configuration {
  let args = try parseCommandLineArguments(from̉: args)
  return try configurationForSwiftPMEntryPoint(from: args)
}

@Suite("Swift Package Manager Integration Tests")
struct SwiftPMTests {
  @Test("Command line arguments are available")
  func commandLineArguments() {
    // We can't meaningfully check the actual values of this process' arguments,
    // but we can check that the arguments() function has a non-empty result.
    #expect(!CommandLine.arguments().isEmpty)
  }

  @Test("--parallel/--no-parallel argument")
  func parallel() throws {
    var configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH"])
    #expect(configuration.isParallelizationEnabled)

    configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--parallel"])
    #expect(configuration.isParallelizationEnabled)

    configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--no-parallel"])
    #expect(!configuration.isParallelizationEnabled)
  }

  @Test("No --filter or --skip argument")
  func defaultFiltering() async throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH"])
    let test1 = Test(name: "hello") {}
    let test2 = Test(name: "goodbye") {}
    let plan = await Runner.Plan(tests: [test1, test2], configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(test1))
    #expect(planTests.contains(test2))
  }

  @Test("--filter argument")
  @available(_regexAPI, *)
  func filter() async throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--filter", "hello"])
    let test1 = Test(name: "hello") {}
    let test2 = Test(name: "goodbye") {}
    let plan = await Runner.Plan(tests: [test1, test2], configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(test1))
    #expect(!planTests.contains(test2))
  }

  @Test("Multiple --filter arguments")
  @available(_regexAPI, *)
  func multipleFilter() async throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--filter", "hello", "--filter", "sorry"])
    let test1 = Test(name: "hello") {}
    let test2 = Test(name: "goodbye") {}
    let test3 = Test(name: "sorry") {}
    let plan = await Runner.Plan(tests: [test1, test2, test3], configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(test1))
    #expect(!planTests.contains(test2))
    #expect(planTests.contains(test3))
  }

  @Test("--filter or --skip argument with bad regex")
  func badArguments() throws {
    #expect(throws: (any Error).self) {
      _ = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--filter", "("])
    }
    #expect(throws: (any Error).self) {
      _ = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--skip", ")"])
    }
  }

  @Test("--skip argument")
  @available(_regexAPI, *)
  func skip() async throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--skip", "hello"])
    let test1 = Test(name: "hello") {}
    let test2 = Test(name: "goodbye") {}
    let plan = await Runner.Plan(tests: [test1, test2], configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(!planTests.contains(test1))
    #expect(planTests.contains(test2))
  }

  @Test(".hidden trait")
  func hidden() async throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH"])
    let test1 = Test(name: "hello") {}
    let test2 = Test(.hidden, name: "goodbye") {}
    let plan = await Runner.Plan(tests: [test1, test2], configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(test1))
    #expect(!planTests.contains(test2))
  }

  @Test("--filter/--skip arguments and .hidden trait")
  @available(_regexAPI, *)
  func filterAndSkipAndHidden() async throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--filter", "hello", "--skip", "hello2"])
    let test1 = Test(name: "hello") {}
    let test2 = Test(name: "hello2") {}
    let test3 = Test(.hidden, name: "hello") {}
    let test4 = Test(.hidden, name: "hello2") {}
    let plan = await Runner.Plan(tests: [test1, test2, test3, test4], configuration: configuration)
    let planTests = plan.steps.map(\.test)
    #expect(planTests.contains(test1))
    #expect(!planTests.contains(test2))
    #expect(!planTests.contains(test3))
    #expect(!planTests.contains(test4))
  }

#if !SWT_NO_FILE_IO
  @Test("--xunit-output argument (bad path)")
  func xunitOutputWithBadPath() {
    // Test that a bad path produces an error.
    #expect(throws: CError.self) {
      _ = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--xunit-output", "/nonexistent/path/we/cannot/write/to"])
    }
  }

  @Test("--xunit-output argument (writes to file)")
  func xunitOutputIsWrittenToFile() throws {
    // Test that a file is opened when requested. Testing of the actual output
    // occurs in ConsoleOutputRecorderTests.
    let tempDirPath = try temporaryDirectory()
    let temporaryFilePath = appendPathComponent("\(UInt64.random(in: 0 ..< .max))", to: tempDirPath)
    defer {
      _ = remove(temporaryFilePath)
    }
    do {
      let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--xunit-output", temporaryFilePath])
      let eventContext = Event.Context()
      configuration.eventHandler(Event(.runStarted, testID: nil, testCaseID: nil), eventContext)
      configuration.eventHandler(Event(.runEnded, testID: nil, testCaseID: nil), eventContext)
    }

    let fileHandle = try FileHandle(forReadingAtPath: temporaryFilePath)
    let fileContents = try fileHandle.readToEnd()
    #expect(!fileContents.isEmpty)
    #expect(fileContents.contains(UInt8(ascii: "<")))
    #expect(fileContents.contains(UInt8(ascii: ">")))
  }

#if canImport(Foundation)
  func decodeEventStream(fromFileAtPath path: String) throws -> [EventAndContextSnapshot] {
    try FileHandle(forReadingAtPath: path).readToEnd()
      .split(separator: 10) // "\n"
      .map { line in
        try line.withUnsafeBytes { line in
          try JSON.decode(EventAndContextSnapshot.self, from: line)
        }
      }
  }

  @Test("--experimental-event-stream-output argument (writes to a stream and can be read back)")
  func eventStreamOutput() async throws {
    // Test that events are successfully streamed to a file and can be read
    // back as snapshots.
    let tempDirPath = try temporaryDirectory()
    let temporaryFilePath = appendPathComponent("\(UInt64.random(in: 0 ..< .max))", to: tempDirPath)
    defer {
      _ = remove(temporaryFilePath)
    }
    do {
      let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--experimental-event-stream-output", temporaryFilePath])
      let eventContext = Event.Context()
      configuration.handleEvent(Event(.runStarted, testID: nil, testCaseID: nil), in: eventContext)
      do {
        let test = Test {}
        let eventContext = Event.Context(test: test)
        configuration.handleEvent(Event(.testStarted, testID: test.id, testCaseID: nil), in: eventContext)
        configuration.handleEvent(Event(.testEnded, testID: test.id, testCaseID: nil), in: eventContext)
      }
      configuration.handleEvent(Event(.runEnded, testID: nil, testCaseID: nil), in: eventContext)
    }

    let decodedEvents = try decodeEventStream(fromFileAtPath: temporaryFilePath)
    #expect(decodedEvents.count == 4)
  }
#endif
#endif

  @Test("--repetitions argument (alone)")
  @available(_regexAPI, *)
  func repetitions() throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--repetitions", "2468"])
    #expect(configuration.repetitionPolicy.maximumIterationCount == 2468)
    #expect(configuration.repetitionPolicy.continuationCondition == nil)
  }

  @Test("--repeat-until pass argument (alone)")
  @available(_regexAPI, *)
  func repeatUntilPass() throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--repeat-until", "pass"])
    #expect(configuration.repetitionPolicy.maximumIterationCount == .max)
    #expect(configuration.repetitionPolicy.continuationCondition == .whileIssueRecorded)
  }

  @Test("--repeat-until fail argument (alone)")
  @available(_regexAPI, *)
  func repeatUntilFail() throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--repeat-until", "fail"])
    #expect(configuration.repetitionPolicy.maximumIterationCount == .max)
    #expect(configuration.repetitionPolicy.continuationCondition == .untilIssueRecorded)
  }

  @Test("--repeat-until argument with garbage value (alone)")
  @available(_regexAPI, *)
  func repeatUntilGarbage() {
    #expect(throws: (any Error).self) {
      _ = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--repeat-until", "qwertyuiop"])
    }
  }

  @Test("--repetitions and --repeat-until arguments")
  @available(_regexAPI, *)
  func repetitionsAndRepeatUntil() throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--repetitions", "2468", "--repeat-until", "pass"])
    #expect(configuration.repetitionPolicy.maximumIterationCount == 2468)
    #expect(configuration.repetitionPolicy.continuationCondition == .whileIssueRecorded)
  }

  @Test("list subcommand")
  func list() async throws {
    let testIDs = await listTestsForSwiftPM(Test.all)
    let currentTestID = try #require(
      Test.current
        .flatMap(\.id.parent)
        .map(String.init(describing:))
    )
    #expect(testIDs.contains(currentTestID))
  }
}
