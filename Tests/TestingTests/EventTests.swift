//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_SNAPSHOT_TYPES
@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
private import _TestingInternals

@Suite("Event Tests")
struct EventTests {
#if canImport(Foundation)
  @Test("Event's and Event.Kinds's Codable Conformances",
        arguments: [
          Event.Kind.expectationChecked(
            Expectation(
              evaluatedExpression: __Expression("SyntaxNode"),
              mismatchedErrorDescription: "Mismatched Error Description",
              differenceDescription: "Difference Description",
              isPassing: false,
              isRequired: true,
              sourceLocation: SourceLocation(fileID: "M/f.swift", filePath: "/f.swift", line: 1, column: 1)
            )
          ),
          Event.Kind.testSkipped(
            SkipInfo(
              comment: "Comment",
              sourceContext: SourceContext(
                backtrace: Backtrace.current(),
                sourceLocation: SourceLocation(fileID: "M/f.swift", filePath: "/f.swift", line: 1, column: 1)
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
                         sourceLocation: #_sourceLocation)
    let testCaseID = Test.Case.ID(argumentIDs: nil, discriminator: nil, isStable: true)
    let event = Event(kind, testID: testID, testCaseID: testCaseID, instant: .now)
    let eventSnapshot = Event.Snapshot(snapshotting: event)
    let decoded = try JSON.encodeAndDecode(eventSnapshot)

    #expect(String(describing: decoded) == String(describing: eventSnapshot))
  }

  @Test("Event.Contexts's Codable Conformances")
  func codable() async throws {
    let eventContext = Event.Context(test: .current, testCase: .current, configuration: .current)
    let snapshot = Event.Context.Snapshot(snapshotting: eventContext)

    let decoded = try JSON.encodeAndDecode(snapshot)

    #expect(String(describing: decoded.test) == String(describing: eventContext.test.map(Test.Snapshot.init(snapshotting:))))
    #expect(String(describing: decoded.testCase) == String(describing: eventContext.testCase.map(Test.Case.Snapshot.init(snapshotting:))))
  }
#endif
}
#endif

// MARK: -

#if canImport(Foundation)
private import _Testing_ExperimentalInfrastructure
import Foundation

private func MockXCTAssert(_ condition: Bool, _ message: String, _ sourceLocation: SourceLocation = #_sourceLocation) {
  #expect(throws: Never.self) {
    if condition {
      return
    }
    guard let fallbackEventHandler = fallbackEventHandler() else {
      return
    }

    let jsonObject: [String: Any] = [
      "version": 0,
      "kind": "event",
      "payload": [
        "kind": "issueRecorded",
        "instant": [
          "absolute": 0.0,
          "since1970": Date().timeIntervalSince1970,
        ],
        "issue": [
          "isKnown": false,
          "sourceLocation": [
            "fileID": sourceLocation.fileID,
            "_filePath": sourceLocation._filePath,
            "line": sourceLocation.line,
            "column": sourceLocation.column,
          ]
        ],
        "messages": [
          [
            "symbol": "fail",
            "text": message
          ]
        ],
      ],
    ]

    let json = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
    json.withUnsafeBytes { json in
      fallbackEventHandler("0", json.baseAddress!, json.count, nil)
    }
  }
}

private func MockXCTAttachmentAdd(_ string: String, named name: String) {
  #expect(throws: Never.self) {
    guard let fallbackEventHandler = fallbackEventHandler() else {
      return
    }

    let bytes = try #require(string.data(using: .utf8)?.base64EncodedString())

    let jsonObject: [String: Any] = [
      "version": 0,
      "kind": "event",
      "payload": [
        "kind": "valueAttached",
        "instant": [
          "absolute": 0.0,
          "since1970": Date().timeIntervalSince1970,
        ],
        "attachment": [
          "_bytes": bytes,
          "_preferredName": name
        ],
        "messages": [],
      ],
    ]

    let json = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
    json.withUnsafeBytes { json in
      fallbackEventHandler("0", json.baseAddress!, json.count, nil)
    }
  }
}

@Suite struct `Fallback event handler tests` {
  @Test func `Fallback event handler is set`() {
    #expect(fallbackEventHandler() != nil)
  }

  @Test func `Fallback event handler is invoked for issue`() async {
    await confirmation("Issue recorded") { issueRecorded in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        guard case .issueRecorded = event.kind else {
          return
        }
        issueRecorded()
      }

      await Test {
        MockXCTAssert(1 == 2, "I'm bad at math!")
      }.run(configuration: configuration)
    }
  }

  @Test func `Attachment is passed to fallback event handler`() async {
    MockXCTAttachmentAdd("0123456789", named: "numbers.txt")
    await confirmation("Attachment recorded") { valueAttached in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }
        #expect(throws: Never.self) {
          let estimatedByteCount = try #require(attachment.attachableValue.estimatedAttachmentByteCount)
          #expect(estimatedByteCount == 10)
        }
        #expect(attachment.preferredName == "numbers.txt")

        valueAttached()
      }

      await Test {
        MockXCTAttachmentAdd("0123456789", named: "numbers.txt")
      }.run(configuration: configuration)
    }
  }
}
#endif
