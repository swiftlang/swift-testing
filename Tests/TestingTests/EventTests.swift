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
@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
private import TestingInternals

@Suite("Event Tests")
struct EventTests {
#if canImport(Foundation)
  @Test("Event's and Event.Kinds's Codable Conformances",
        arguments: [
          Event.Kind.expectationChecked(
            Expectation(
              evaluatedExpression: Expression("SyntaxNode"),
              mismatchedErrorDescription: "Mismatched Error Description",
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
    let testCaseID = Test.Case.ID(argumentIDs: nil)
    let event = Event(kind, testID: testID, testCaseID: testCaseID, instant: .now)
    let eventSnapshot = Event.Snapshot(snapshotting: event)
    let encoded = try JSONEncoder().encode(eventSnapshot)
    let decoded = try JSONDecoder().decode(Event.Snapshot.self, from: encoded)

    #expect(String(describing: decoded) == String(describing: eventSnapshot))
  }

  @Test("Event.Contexts's Codable Conformances")
  func codable() async throws {
    let eventContext = Event.Context()
    let snapshot = Event.Context.Snapshot(snapshotting: eventContext)

    let encoded = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(Event.Context.Snapshot.self, from: encoded)

    #expect(String(describing: decoded.test) == String(describing: eventContext.test.map(Test.Snapshot.init(snapshotting:))))
    #expect(String(describing: decoded.testCase) == String(describing: eventContext.testCase.map(Test.Case.Snapshot.init(snapshotting:))))
  }
#endif
}
