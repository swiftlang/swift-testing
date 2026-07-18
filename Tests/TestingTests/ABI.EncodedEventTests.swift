//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

#if !SWT_NO_CODABLE
@Suite struct `ABI.EncodedEventTests` {
  /// Creates an EncodedEvent from a JSON string.
  ///
  /// - Throws: If the JSON doesn't represent a valid EncodedEvent.
  private func encodedEvent(
    _ json: String,
  ) throws -> ABI.EncodedEvent<ABI.CurrentVersion> {
    var json = json
    return try json.withUTF8 { json in
      try JSON.decode(ABI.EncodedEvent<ABI.CurrentVersion>.self, from: UnsafeRawBufferPointer(json))
    }
  }

  @Test func `Decoded event always has nil testID and testCaseID`() throws {
    let event = try encodedEvent(
      """
      {
        "kind": "testStarted",
        "instant": {"absolute": 123, "since1970": 456},
        "messages": [],
        "testID": "SomeValidTestID/testFunc()"
      }
      """)
    let decoded = try #require(Event(decoding: event))

    #expect(decoded.testID == nil)
    #expect(decoded.testCaseID == nil)
  }

  @Test(arguments: [
    "runStarted",
    "runEnded",
    "testStarted",
    "testEnded",
    "testCaseStarted",
    "testCaseEnded",
    // Following `kind`s need SkipInfo which nominally requires _sourceLocation.
    // However, an empty placeholder SkipInfo can be provided when decoding.
    // vvv
    "testCaseCancelled",
    "testSkipped",
    "testCancelled",
  ]) func `Successfully decode events which don't require associated info`(kind: String) throws {
    let event = try encodedEvent(
      """
      {
        "kind": "\(kind)",
        "instant": {"absolute": 123, "since1970": 456},
        "messages": [],
      }
      """)

    #expect(Event(decoding: event) != nil)
  }

  @Test(arguments: [
    "issueRecorded",  // Needs issue details
    "valueAttached",  // Needs attachment details
  ]) func `Events without required associated info fail to decode`(kind: String) throws {
    let event = try encodedEvent(
      """
      {
        "kind": "\(kind)",
        "instant": {"absolute": 123, "since1970": 456},
        "messages": [],
      }
      """)

    #expect(Event(decoding: event) == nil)
  }

  @Test func `Decode issueRecorded`() throws {
    let event = try encodedEvent(
      """
      {
        "kind": "issueRecorded",
        "instant": {"absolute": 0, "since1970": 0},
        "messages": [],
        "issue": {"isKnown": true}
      }
      """)
    let decoded = try #require(Event(decoding: event))

    guard case .issueRecorded(let issue) = decoded.kind else {
      Issue.record("Expected issueRecorded but got wrong kind \(decoded.kind)")
      return
    }
    #expect(issue.isKnown)
  }

  @Test func `Decode valueAttached`() throws {
    let event = try encodedEvent(
      """
      {
        "kind": "valueAttached",
        "instant": {"absolute": 0, "since1970": 0},
        "messages": [],
        "attachment": {"path": "/tmp/important-cheese.txt"}
      }
      """)
    let decoded = try #require(Event(decoding: event))

    guard case .valueAttached = decoded.kind else {
      Issue.record("Expected valueAttached but got wrong kind \(decoded.kind)")
      return
    }
  }

  // MARK: Iteration

  @Test func `Encode iteration`() throws {
    let test = Test {}
    let event = Event(.testCaseStarted, testID: .init(["SomeValidTestID", "testFunc()"]), testCaseID: nil)
    let context = Event.Context(test: test, testCase: nil, iteration: 2, configuration: nil)
    let encoded = try #require(ABI.EncodedEvent<ABI.v6_4>(encoding: event, in: context, messages: []))

    #expect(encoded.iteration == 2)

    try JSON.withEncoding(of: encoded) { buf in
      let str = String(decoding: buf, as: UTF8.self)
      #expect(str.contains(#""iteration":2"#))
    }

    let encoded6_3 = try #require(ABI.EncodedEvent<ABI.v6_3>(encoding: event, in: context, messages: []))
    #expect(encoded6_3.iteration == nil)
    try JSON.withEncoding(of: encoded6_3) { buf in
      let str = String(decoding: buf, as: UTF8.self)
      #expect(!str.contains(#"iteration"#))
    }
  }

  @Test func `Decode iteration`() throws {
    var event = try encodedEvent(
      """
      {
        "kind": "testStarted",
        "instant": {"absolute": 123, "since1970": 456},
        "messages": [],
        "testID": "SomeValidTestID/testFunc()",
        "iteration": 2
      }
      """)
    #expect(event.iteration == 2)

    event = try encodedEvent(
      """
      {
        "kind": "testStarted",
        "instant": {"absolute": 123, "since1970": 456},
        "messages": [],
        "testID": "SomeValidTestID/testFunc()"
      }
      """)
    #expect(event.iteration == nil)
  }

  @Test func `Encoded event for non-parameterized test doesn't add testCase`() async {
    var configuration = Configuration()
    configuration.eventHandler = { event, context in
      guard let encoded = ABI.EncodedEvent<ABI.CurrentVersion>(encoding: event, in: context, messages: []) else {
        return
      }
      switch encoded.kind {
      case .testStarted, .testEnded, .testCancelled:
        #expect(encoded._testCase == nil)
      case .testCaseStarted, .testCaseEnded, .testCaseCancelled:
        Issue.record("Should not encode test case events for non-parameterized test")
      default:
        return
      }
    }
    let test = Test() {}
    await test.run(configuration: configuration)
  }
}
#endif
