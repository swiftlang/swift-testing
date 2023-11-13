//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalTestRunning) @_spi(ExperimentalEventHandling) import Testing
import Foundation

@Suite("Swift Package Manager Integration Tests")
struct SwiftPMTests {
  @Test("Command line arguments are available")
  func commandLineArguments() {
    // We can't meaningfully check the actual values of this process' arguments,
    // but we can check that the arguments() function has a non-empty result.
    #expect(!CommandLine.arguments().isEmpty)
  }

  @Test("--parallel argument")
  func parallel() throws {
    var configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH"])
    #expect(!configuration.isParallelizationEnabled)
    
    configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--parallel"])
    #expect(configuration.isParallelizationEnabled)
  }

  @Test("No --filter or --skip argument")
  func defaultFiltering() throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH"])
    let testFilter = try #require(configuration.testFilter)
    let test1 = Test(name: "hello") {}
    #expect(testFilter(test1))
    let test2 = Test(name: "goodbye") {}
    #expect(testFilter(test2))
  }

  @Test("--filter argument")
  func filter() throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--filter", "hello"])
    let testFilter = try #require(configuration.testFilter)
    let test1 = Test(name: "hello") {}
    #expect(testFilter(test1))
    let test2 = Test(name: "goodbye") {}
    #expect(!testFilter(test2))
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
  func skip() throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--skip", "hello"])
    let testFilter = try #require(configuration.testFilter)
    let test1 = Test(name: "hello") {}
    #expect(!testFilter(test1))
    let test2 = Test(name: "goodbye") {}
    #expect(testFilter(test2))
  }

  @Test(".hidden trait")
  func hidden() throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH"])
    let testFilter = try #require(configuration.testFilter)
    let test1 = Test(name: "hello") {}
    #expect(testFilter(test1))
    let test2 = Test(.hidden, name: "goodbye") {}
    #expect(!testFilter(test2))
  }

  @Test("--filter/--skip arguments and .hidden trait")
  func filterAndSkipAndHidden() throws {
    let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--filter", "hello", "--skip", "hello2"])
    let testFilter = try #require(configuration.testFilter)
    let test1 = Test(name: "hello") {}
    #expect(testFilter(test1))
    let test2 = Test(.hidden, name: "hello") {}
    #expect(!testFilter(test2))
    let test3 = Test(.hidden, name: "hello2") {}
    #expect(!testFilter(test3))
  }

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
    // occurs in EventRecorderTests.
    let temporaryFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
    defer {
      try? FileManager.default.removeItem(at: temporaryFileURL)
    }
    do {
      let configuration = try configurationForSwiftPMEntryPoint(withArguments: ["PATH", "--xunit-output", temporaryFileURL.path])
      let eventContext = Event.Context()
      configuration.eventHandler(Event(.runStarted, testID: nil), eventContext)
      configuration.eventHandler(Event(.runEnded, testID: nil), eventContext)
    }
    #expect(try temporaryFileURL.checkResourceIsReachable())
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
