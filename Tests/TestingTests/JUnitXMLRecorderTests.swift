//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_FOUNDATION || canImport(FoundationXML)
@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

#if !SWT_NO_FOUNDATION
import Foundation
#endif
#if canImport(FoundationXML)
import FoundationXML
#endif
#if !SWT_TARGET_OS_APPLE && canImport(Synchronization)
import Synchronization
#endif

/// A parser delegate that collects report totals and counts result elements.
final class JUnitXMLCountsDelegate: NSObject, XMLParserDelegate {
  /// The attributes of the test suite element.
  var suiteAttributes: [String: String]?

  /// The number of test case elements.
  var testCaseCount = 0

  /// The number of skipped result elements.
  var skippedTestCaseCount = 0

  /// Get the value of an attribute of the test suite element parsed as an integer.
  func integerAttribute(_ name: String) throws -> Int {
    let suiteAttributes = try #require(self.suiteAttributes)
    let value = try #require(suiteAttributes[name])
    return try #require(Int(value))
  }

  func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    switch elementName {
    case "testsuite":
      suiteAttributes = attributeDict
    case "testcase":
      testCaseCount += 1
    case "skipped":
      skippedTestCaseCount += 1
    default:
      break
    }
  }
}

@Suite("JUnit XML Recorder Tests")
struct JUnitXMLRecorderTests {
  final class Stream: TextOutputStream, Sendable {
    let buffer = Mutex<String>("")

    @Sendable func write(_ string: String) {
      buffer.withLock {
        $0.append(string)
      }
    }
  }

  @Test(
    "JUnit XML totals match reported test cases",
    arguments: [
      (0, 0, 0, 0),
      (0, 3, 3, 3),
      (1, 0, 1, 0),
      (1, 1, 2, 1),
    ]
  )
  func junitXMLCountsStartedAndSkippedTests(started: Int, skipped: Int, expectedTests: Int, expectedSkipped: Int) async throws {
    let stream = Stream()
    let recorder = Event.JUnitXMLRecorder(writingUsing: stream.write)
    // Suite events must not contribute to the number of reported tests.
    let suite = try #require(await test(for: WrittenTests.self))
    let startedTests = (0 ..< started).map { Test(name: "started \($0)") {} }
    let skippedTests = (0 ..< skipped).map { Test(name: "skipped \($0)") {} }

    recorder.record(Event(.testDiscovered, testID: suite.id, testCaseID: nil), in: Event.Context(test: suite, testCase: nil, iteration: nil, configuration: nil))
    for test in startedTests + skippedTests {
      recorder.record(Event(.testDiscovered, testID: test.id, testCaseID: nil), in: Event.Context(test: test, testCase: nil, iteration: nil, configuration: nil))
    }

    let runContext = Event.Context(test: nil, testCase: nil, iteration: nil, configuration: nil)
    recorder.record(Event(.runStarted, testID: nil, testCaseID: nil), in: runContext)

    let suiteContext = Event.Context(test: suite, testCase: nil, iteration: nil, configuration: nil)
    if started > 0 {
      recorder.record(Event(.testStarted, testID: suite.id, testCaseID: nil), in: suiteContext)
    } else if skipped > 0 {
      recorder.record(Event(.testSkipped(.init(sourceContext: .init())), testID: suite.id, testCaseID: nil), in: suiteContext)
    }

    for test in startedTests {
      let context = Event.Context(test: test, testCase: nil, iteration: nil, configuration: nil)
      recorder.record(Event(.testStarted, testID: test.id, testCaseID: nil), in: context)
      recorder.record(Event(.testEnded, testID: test.id, testCaseID: nil), in: context)
    }
    for test in skippedTests {
      let context = Event.Context(test: test, testCase: nil, iteration: nil, configuration: nil)
      recorder.record(Event(.testSkipped(.init(sourceContext: .init())), testID: test.id, testCaseID: nil), in: context)
    }

    if started > 0 {
      recorder.record(Event(.testEnded, testID: suite.id, testCaseID: nil), in: suiteContext)
    }
    recorder.record(Event(.runEnded, testID: nil, testCaseID: nil), in: runContext)

    let parser = XMLParser(data: Data(stream.buffer.rawValue.utf8))
    let delegate = JUnitXMLCountsDelegate()
    parser.delegate = delegate
    try #require(parser.parse())
    #expect(try delegate.integerAttribute("tests") == expectedTests)
    #expect(try delegate.integerAttribute("skipped") == expectedSkipped)
    #expect(try delegate.integerAttribute("failures") == 0)
    #expect(delegate.testCaseCount == expectedTests)
    #expect(delegate.skippedTestCaseCount == expectedSkipped)
  }

  @Test("JUnit XML counts tests selected by the runner")
  func junitXMLCountsTestsSelectedByRunner() async throws {
    let stream = Stream()
    let recorder = Event.JUnitXMLRecorder(writingUsing: stream.write)
    let testCaseStarts = Mutex(0)
    var configuration = Configuration()
    configuration.repetitionPolicy = .repeating(maximumIterationCount: 2)
    configuration.eventHandler = { event, context in
      if case .testCaseStarted = event.kind {
        testCaseStarts.withLock { $0 += 1 }
      }
      recorder.record(event, in: context)
    }

    await runTest(for: JUnitSkippedCountFixtures.self, configuration: configuration)

    let parser = XMLParser(data: Data(stream.buffer.rawValue.utf8))
    let delegate = JUnitXMLCountsDelegate()
    parser.delegate = delegate
    try #require(parser.parse())
    // Count test functions even when parameter values run more than once.
    #expect(try delegate.integerAttribute("tests") == 5)
    #expect(try delegate.integerAttribute("skipped") == 4)
    #expect(try delegate.integerAttribute("failures") == 0)
    #expect(delegate.testCaseCount == 5)
    #expect(delegate.skippedTestCaseCount == 4)
    #expect(testCaseStarts.withLock { $0 } == 6)
  }
}

// MARK: - Fixtures

/// Tests that exercise the report totals for passing and skipped results.
@Suite(.hidden)
struct JUnitSkippedCountFixtures {
  @Test(.hidden, arguments: [1, 2, 3])
  func passing(_ value: Int) {}

  @Test(.hidden, .disabled())
  func directlySkipped() {
    Issue.record("A disabled test should not run.")
  }

  @Test(.hidden, arguments: [Int]())
  func emptyParameterCollection(_ value: Int) {
    Issue.record("A test with no arguments should not run.")
  }

  @Suite(.hidden, .disabled())
  struct Disabled {
    @Test(.hidden)
    func first() {
      Issue.record("A disabled suite test should not run.")
    }

    @Test(.hidden)
    func second() {
      Issue.record("A disabled suite test should not run.")
    }
  }
}
#endif
