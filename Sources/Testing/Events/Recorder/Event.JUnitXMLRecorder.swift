//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Event {
  /// A type which handles ``Event`` instances and outputs representations of
  /// them as JUnit-compatible XML.
  @_spi(ForToolsIntegrationOnly)
  public struct JUnitXMLRecorder: Sendable {
    /// The write function for this event recorder.
    var write: @Sendable (String) -> Void

    /// A type that contains mutable context for ``Event/JUnitXMLRecorder``.
    ///
    /// - Bug: Although the data being tracked is different, this type could
    ///   potentially be reconciled with
    ///   ``Event/ConsoleOutputRecorder/Context``.
    private struct _Context: Sendable {
      /// The instant at which the run started.
      var runStartInstant: Test.Clock.Instant?

      /// The number of tests started or skipped during the run.
      ///
      /// This value does not include test suites.
      var testCount = 0

      /// A type describing data tracked on a per-test basis.
      struct TestData: Sendable {
        /// The ID of the test.
        var id: Test.ID

        /// The instant at which the test started.
        var startInstant: Test.Clock.Instant

        /// The instant at which the test started.
        var endInstant: Test.Clock.Instant?

        /// Any issues recorded for the test.
        var issues = [Issue]()
      }

      /// Data tracked on a per-test basis.
      var testData = Graph<String, TestData?>()
    }

    /// This event recorder's mutable context about events it has received,
    /// which may be used to inform how subsequent events are written.
    private var _context = Locked(rawValue: _Context())

    /// Initialize a new event recorder.
    ///
    /// - Parameters:
    ///   - write: A closure that writes output to its destination. The closure
    ///     may be invoked concurrently.
    ///
    /// Output from the testing library is written using `write`.
    init(writingUsing write: @escaping @Sendable (String) -> Void) {
      self.write = write
    }
  }
}

extension Event.JUnitXMLRecorder {
  /// Record the specified event by generating a representation of it as a
  /// human-readable string.
  ///
  /// - Parameters:
  ///   - event: The event to record.
  ///   - eventContext: The context associated with the event.
  ///
  /// - Returns: A string description of the event, or `nil` if there is nothing
  ///   useful to output for this event.
  private func _record(_ event: borrowing Event, in eventContext: borrowing Event.Context) -> String? {
    let instant = event.instant
    let test = eventContext.test

    switch event.kind {
    case .runStarted:
      _context.withLock { context in
        context.runStartInstant = instant
      }
      return #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuites>

        """#
    case .testStarted where false == test?.isSuite:
      let id = test!.id
      let keyPath = id.keyPathRepresentation
      _context.withLock { context in
        context.testCount += 1
        context.testData[keyPath] = _Context.TestData(id: id, startInstant: instant)
      }
      return nil
    case .testEnded where false == test?.isSuite:
      let id = test!.id
      let keyPath = id.keyPathRepresentation
      _context.withLock { context in
        context.testData[keyPath]?.endInstant = instant
      }
      return nil
    case .testSkipped where false == test?.isSuite:
      return nil
    case let .issueRecorded(issue):
      if issue.isKnown {
        return nil
      }
      guard let id = test?.id else {
        return nil // FIXME: handle issues without known tests
      }
      let keyPath = id.keyPathRepresentation
      _context.withLock { context in
        context.testData[keyPath]?.issues.append(issue)
      }
      return nil
    case .runEnded:
      return _context.withLock { context in
        let issueCount = context.testData
          .compactMap(\.value?.issues.count)
          .reduce(into: 0, +=)
        let durationNanoseconds = context.runStartInstant.map { $0.nanoseconds(until: instant) } ?? 0
        let durationSeconds = Double(durationNanoseconds) / 1_000_000_000
        return #"""
            <testsuite name="TestResults" errors="0" tests="\#(context.testCount)" failures="\#(issueCount)" time="\#(durationSeconds)">
          \#(Self._xml(for: context.testData))
            </testsuite>
          </testsuites>

          """#
      }
    default:
      return nil
    }
  }

  /// Generate XML for a graph of test data.
  ///
  /// - Parameters:
  ///   - testDataGraph: The test data graph.
  ///
  /// - Returns: A string containing (partial) XML for the given test graph.
  ///
  /// This function calls itself recursively as it walks `testDataGraph` in
  /// order to build up the XML output for all nodes therein.
  private static func _xml(for testDataGraph: Graph<String, _Context.TestData?>) -> String {
    var result = [String]()

    if let testData = testDataGraph.value {
      let id = testData.id
      let classNameComponents = CollectionOfOne(id.moduleName) + id.nameComponents.dropLast()
      let className = classNameComponents.joined(separator: ".")
      let name = id.nameComponents.last!
      let durationNanoseconds = testData.startInstant.nanoseconds(until: testData.endInstant ?? .now)
      let durationSeconds = Double(durationNanoseconds) / 1_000_000_000
      if testData.issues.isEmpty {
        result.append(#"    <testcase classname="\#(className)" name="\#(name)" time="\#(durationSeconds)" />"#)
      } else {
        result.append(#"    <testcase classname="\#(className)" name="\#(name)" time="\#(durationSeconds)">"#)
        result += testData.issues.lazy
          .map(String.init(describing:))
          .map { #"      <failure message="\#(Self._escapeForXML($0))" />"# }
        result.append(#"    </testcase>"#)
      }
    } else {
      for childGraph in testDataGraph.children.values {
        result.append(_xml(for: childGraph))
      }
    }

    return result.joined(separator: "\n")
  }

  /// Escape a single Unicode character for use in an XML-encoded string.
  ///
  /// - Parameters:
  ///   - character: The character to escape.
  ///
  /// - Returns: `character`, or a string containing its escaped form.
  private static func _escapeForXML(_ character: Character) -> String {
    if character == #"""# {
      "&quot;"
    } else if !character.isASCII {
      character.unicodeScalars.lazy
        .map(\.value)
        .map { "&#\($0);" }
        .joined()
    } else {
      String(character)
    }
  }

  /// Escape a string for use in XML.
  ///
  /// - Parameters:
  ///   - string: The string to escape.
  ///
  /// - Returns: A copy of `string` that has been escaped for XML.
  private static func _escapeForXML(_ string: String) -> String {
    string.lazy.map(_escapeForXML).joined()
  }

  @discardableResult public func record(_ event: borrowing Event, in context: borrowing Event.Context) -> Bool {
    if let output = _record(event, in: context) {
      write(output)
      return true
    }
    return false
  }
}
