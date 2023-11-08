//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalEventHandling) @_spi(ExperimentalTestRunning) import Testing
#if !os(Windows)
import RegexBuilder
#endif
import Foundation

@Suite("EventRecorder Tests")
struct EventRecorderTests {
  final class Stream: TextOutputStream, Sendable {
    let buffer = Locked<String>(wrappedValue: "")

    @Sendable func write(_ string: String) {
      buffer.withLock {
        $0.append(string)
      }
    }
  }

  private static var optionCombinations: [[Event.ConsoleOutputRecorder.Option]] {
    var result: [[Event.ConsoleOutputRecorder.Option]] = [
      [],
      [.useANSIEscapeCodes],
      [.use256ColorANSIEscapeCodes],
      [.useANSIEscapeCodes, .use256ColorANSIEscapeCodes],
    ]
#if os(macOS)
    result += [
      [.useSFSymbols],
      [.useSFSymbols, .useANSIEscapeCodes],
      [.useSFSymbols, .use256ColorANSIEscapeCodes],
      [.useSFSymbols, .useANSIEscapeCodes, .use256ColorANSIEscapeCodes],
    ]
#endif
    return result
  }

  @Test("Writing events", arguments: optionCombinations)
  func writingToStream(options: [Event.ConsoleOutputRecorder.Option]) async throws {
    let stream = Stream()

    var configuration = Configuration()
    configuration.deliverExpectationCheckedEvents = true
    let eventRecorder = Event.ConsoleOutputRecorder(options: options, writingUsing: stream.write)
    configuration.eventHandler = { event, context in
      eventRecorder.record(event, in: context)
    }

    await runTest(for: WrittenTests.self, configuration: configuration)

    let buffer = stream.buffer.wrappedValue
    #expect(buffer.contains("failWhale"))
    #expect(buffer.contains("Whales fail."))
#if !SWT_NO_UNSTRUCTURED_TASKS
    #expect(buffer.contains("Whales fail asynchronously."))
#endif
    #expect(buffer.contains("\"abc\" == \"xyz\""))
    #expect(buffer.contains("Not A Lobster"))
    #expect(buffer.contains("i → 5"))
    #expect(buffer.contains("Ocelots don't like the number 3."))

    if options.contains(.useANSIEscapeCodes) {
      #expect(buffer.contains("\u{001B}["))
      #expect(buffer.contains("●"))
    } else {
      #expect(!buffer.contains("\u{001B}["))
      #expect(!buffer.contains("●"))
    }

    #expect(buffer.contains("inserted ["))

    if testsWithSignificantIOAreEnabled {
      print(buffer, terminator: "")
    }
  }

#if !os(Windows)
  @available(_regexAPI, *)
  @Test(
    "Issue counts are summed correctly on test end",
    arguments: [
      "f()": (5, 3),
      "g()": (2, 1),
      "PredictablyFailingTests": (7, 4)
    ]
  )
  func issueCountSummingAtTestEnd(testName: String, issueCount: (total: Int, expected: Int)) async throws {
    let stream = Stream()

    var configuration = Configuration()
    let eventRecorder = Event.ConsoleOutputRecorder(writingUsing: stream.write)
    configuration.eventHandler = { event, context in
      eventRecorder.record(event, in: context)
    }

    await runTest(for: PredictablyFailingTests.self, configuration: configuration)

    let buffer = stream.buffer.wrappedValue
    if testsWithSignificantIOAreEnabled {
      print(buffer, terminator: "")
    }

    let testFailureRegex = Regex {
      One(.anyGraphemeCluster)
      " Test \(testName) failed"
      ZeroOrMore(.any)
      " with "
      Capture { OneOrMore(.digit) } transform: { Int($0) }
      " issue"
      Optionally("s")
      " (including "
      Capture { OneOrMore(.digit) } transform: { Int($0) }
      " known issue"
      Optionally("s")
      ")."
    }
    let match = try #require(
      buffer
        .split(whereSeparator: \.isNewline)
        .compactMap(testFailureRegex.wholeMatch(in:))
        .first
    )
    #expect(issueCount.total == match.output.1)
    #expect(issueCount.expected == match.output.2)
  }
#endif

  @available(_regexAPI, *)
  @Test("Issue counts are omitted on a successful test")
  func issueCountOmittedForPassingTest() async throws {
    let stream = Stream()

    var configuration = Configuration()
    let eventRecorder = Event.ConsoleOutputRecorder(writingUsing: stream.write)
    configuration.eventHandler = { event, context in
      eventRecorder.record(event, in: context)
    }

    await Test(name: "Innocuous Test Name") {
    }.run(configuration: configuration)

    let buffer = stream.buffer.wrappedValue
    if testsWithSignificantIOAreEnabled {
      print(buffer, terminator: "")
    }

    #expect(!buffer.contains("issue"))
  }

#if !os(Windows)
  @available(_regexAPI, *)
  @Test("Issue counts are summed correctly on run end")
  func issueCountSummingAtRunEnd() async throws {
    let stream = Stream()

    var configuration = Configuration()
    let eventRecorder = Event.ConsoleOutputRecorder(writingUsing: stream.write)
    configuration.eventHandler = { event, context in
      eventRecorder.record(event, in: context)
    }

    await runTest(for: PredictablyFailingTests.self, configuration: configuration)

    let buffer = stream.buffer.wrappedValue
    if testsWithSignificantIOAreEnabled {
      print(buffer, terminator: "")
    }

    let runFailureRegex = Regex {
      One(.anyGraphemeCluster)
      " Test run with "
      OneOrMore(.digit)
      " test"
      Optionally("s")
      " failed "
      ZeroOrMore(.any)
      " with "
      Capture { OneOrMore(.digit) } transform: { Int($0) }
      " issue"
      Optionally("s")
      " (including "
      Capture { OneOrMore(.digit) } transform: { Int($0) }
      " known issue"
      Optionally("s")
      ")."
    }
    let match = try #require(
      buffer
        .split(whereSeparator: \.isNewline)
        .compactMap(runFailureRegex.wholeMatch(in:))
        .first
    )
    #expect(match.output.1 == 7)
    #expect(match.output.2 == 4)
  }
#endif

  @Test("JUnitXMLRecorder outputs valid XML")
  func junitXMLIsValid() async throws {
    let stream = Stream()

    var configuration = Configuration()
    configuration.deliverExpectationCheckedEvents = true
    let eventRecorder = Event.JUnitXMLRecorder(writingUsing: stream.write)
    configuration.eventHandler = { event, context in
      eventRecorder.record(event, in: context)
    }

    await runTest(for: WrittenTests.self, configuration: configuration)

    // There is no formal schema for us to test against, so we're just testing
    // that the XML can be parsed by Foundation.

    let xmlString = stream.buffer.wrappedValue
    #expect(xmlString.hasPrefix("<?xml"))
    let xmlData = try #require(xmlString.data(using: .utf8))
    #expect(xmlData.count > 1024)
    let parser = XMLParser(data: xmlData)
    #expect(parser.parse())
    if let error = parser.parserError {
      throw error
    }
  }
}

// MARK: - Fixtures

@Suite(.hidden) struct WrittenTests {
  @Test(.hidden) func failWhale() async {
    Issue.record("Whales fail.")
    await { () async in
      _ = Issue.record("Whales fail asynchronously.")
    }()
  }
  @Test(.hidden) func expectantKangaroo() {
    #expect("abc" == "xyz")
  }
  @Test(.hidden) func successBadger() {}
  @Test(.hidden, .tags(.red, .orange, .green), arguments: 0 ..< 10) func severalLarks(i: Int) {}
  @Test(.hidden, .tags(.purple), arguments: 0 ..< 100) func multitudeOcelot(i: Int) {
    if i == 3 {
      Issue.record("Ocelots don't like the number 3.")
    }
  }
  @Test("Not A Lobster", .hidden) func actuallyCrab() {}
  @Test("Avoid the Komodo", .hidden, .disabled(), .tags(.red, .orange, .yellow, .green, .blue, .purple))
  func angeredKomodo() {}

  @Test("Incensed Quail", .hidden)
  func incensedQuail() throws {
    withKnownIssue {
      struct QuailError: Error {}
      throw QuailError()
    }
  }

  @Test("Unavailable Pigeon", .hidden)
  @available(*, unavailable)
  func unavailablePigeon() {}

  @Test("Future Grouse", .hidden)
  @available(macOS 999.0, iOS 999.0, watchOS 999.0, tvOS 999.0, *)
  func futureGrouse() {}

  @Test("Future Goose", .hidden)
  @available(macOS 999, iOS 999, watchOS 999, tvOS 999, *)
  func futureGoose() {}

  @Test("Future Mouse", .hidden)
  @available(macOS, introduced: 999.0)
  func futureMouse() {}

  @Test("Future Moose", .hidden)
  @available(macOS, introduced: 999.0.0)
  func futureMoose() {}

  @Test(.hidden, .comment("No comment"), .comment("Well, maybe"))
  func commented() {
    Issue.record()
  }

  @Test(.hidden) func diffyDuck() {
    #expect([1, 2, 3] as Array == [1, 2] as Array)
  }

  @Test(.hidden) func woefulWombat() {
    #expect(throws: MyError.self) {
      throw MyDescriptiveError(description: "Woe!")
    }
  }

  @Test(.hidden) func quotationalQuokka() throws {
    throw MyDescriptiveError(description: #""Quotation marks!""#)
  }

  @Test(.hidden) func cornyUnicorn🦄() throws {
    throw MyDescriptiveError(description: #"🦄"#)
  }
}

@Suite(.hidden) struct PredictablyFailingTests {
  @Test(.hidden) func f() {
    #expect(Bool(false))
    #expect(Bool(false))
    withKnownIssue {
      #expect(Bool(false))
      #expect(Bool(false))
      #expect(Bool(false))
    }
  }

  @Test(.hidden) func g() {
    #expect(Bool(false))
    withKnownIssue {
      #expect(Bool(false))
    }
  }
}
