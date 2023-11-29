//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation)
import Foundation
#endif
@testable @_spi(ExperimentalEventHandling) @_spi(ExperimentalParameterizedTesting) @_spi(ExperimentalSnapshotting) @_spi(ExperimentalTestRunning) import Testing
private import TestingInternals

struct EventTests {
#if canImport(Foundation)
  @Test("Event's and Event.Kinds's Codable Conformances",
        arguments: [
          Event.Kind.expectationChecked(
            Expectation(
              sourceCode: SourceCode(kind: .syntaxNode("SyntaxNode")),
              mismatchedErrorDescription: "Mismatched Error Description",
              expandedExpressionDescription: "Expanded Expression Description",
              differenceDescription: "Difference Description",
              isPassing: false,
              isRequired: true,
              sourceLocation: SourceLocation()
            )
          ),
          Event.Kind.testSkipped(
            SkipInfo(
              comment: "Comment",
              sourceContext: SourceContext(
                backtrace: Backtrace.current(),
                sourceLocation: SourceLocation()
              )
            )
          ),
          Event.Kind.issueRecorded(
            Issue(
              kind: .system,
              comments: ["Comment"],
              sourceContext: SourceContext(
                backtrace: nil,
                sourceLocation: nil)
            )
          ),
          Event.Kind.runStarted,
          Event.Kind.runEnded,
          Event.Kind.testCaseStarted,
          Event.Kind.testCaseEnded,
          Event.Kind.testStarted,
          Event.Kind.testEnded,
        ]
  )
  func codable(kind: Event.Kind) async throws {
    let testID = Test.ID(moduleName: "ModuleName",
                         nameComponents: ["NameComponent1", "NameComponent2"],
                         sourceLocation: SourceLocation())
    let testCaseID = Test.Case.ID(argumentIDs: [.init(bytes: .init("a".utf8))])
    let event = Event(kind, testID: testID, testCaseID: testCaseID, instant: .now)
    let eventSnapshot = Event.Snapshot(snapshotting: event)
    let encoded = try JSONEncoder().encode(eventSnapshot)
    let decoded = try JSONDecoder().decode(Event.Snapshot.self, from: encoded)

    #expect(String(describing: decoded) == String(describing: eventSnapshot))
  }
#endif
}
