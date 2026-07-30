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

#if !SWT_NO_ABI_JSON_SCHEMA
@Suite struct `ABI.EncodedEvent Tests` {
  /// Creates an EncodedEvent from a JSON string.
  ///
  /// - Throws: If the JSON doesn't represent a valid EncodedEvent.
  private func encodedEvent<V>(_ version: V.Type, _ json: String) throws -> ABI.EncodedEvent<V> {
    var json = json
    return try json.withUTF8 { json in
      try JSON.decode(ABI.EncodedEvent<V>.self, from: UnsafeRawBufferPointer(json))
    }
  }

  /// Creates an EncodedEvent from a JSON string.
  ///
  /// - Throws: If the JSON doesn't represent a valid EncodedEvent.
  private func encodedEvent(_ json: String) throws -> ABI.EncodedEvent<ABI.CurrentVersion> {
    try encodedEvent(ABI.CurrentVersion.self, json)
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

  @Test func `Encoded instant in event is decodable`() throws {
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

#if !SWT_NO_SUSPENDING_CLOCK
    #expect(decoded.instant.suspending.rawValue == .seconds(123))
#endif
#if !SWT_NO_UTC_CLOCK
    #expect(decoded.instant.wall.rawValue == .seconds(456))
#endif
  }

  @Test func `Encoded event with suspending clock instant only is decodable`() throws {
    let event = try encodedEvent(
      ABI.ExperimentalVersion.self,
      """
      {
        "kind": "testStarted",
        "instant": {"absolute": 123},
        "messages": [],
        "testID": "SomeValidTestID/testFunc()"
      }
      """)
    let decoded = try #require(Event(decoding: event))

#if !SWT_NO_SUSPENDING_CLOCK
    #expect(decoded.instant.suspending.rawValue == .seconds(123))
#endif
#if !SWT_NO_UTC_CLOCK
    #expect(decoded.instant.wall.rawValue > .seconds(123))
#endif
  }

  @Test func `Encoded event with wall clock instant only is decodable`() throws {
    let event = try encodedEvent(
      ABI.ExperimentalVersion.self,
      """
      {
        "kind": "testStarted",
        "instant": {"since1970": 123},
        "messages": [],
        "testID": "SomeValidTestID/testFunc()"
      }
      """)
    let decoded = try #require(Event(decoding: event))

#if !SWT_NO_SUSPENDING_CLOCK
    // The system will have booted well after the UNIX epoch + 123s
    #expect(decoded.instant.suspending.rawValue < .zero)
#endif
#if !SWT_NO_UTC_CLOCK
    #expect(decoded.instant.wall.rawValue == .seconds(123))
#endif
  }

  @Test func `Encoded event with empty instant is decodable`() throws {
    let event = try encodedEvent(
      ABI.ExperimentalVersion.self,
      """
      {
        "kind": "testStarted",
        "instant": {},
        "messages": [],
        "testID": "SomeValidTestID/testFunc()"
      }
      """)
    let before = Test.Clock().now
    let decoded = try #require(Event(decoding: event))
    let after = Test.Clock().now

    #expect(decoded.instant > before)
    #expect(decoded.instant < after)
  }

  @Test func `Encoded event with wall clock instant only fails to decode for older schema version`() throws {
    let event = try encodedEvent(
      ABI.v6_3.self,
      """
      {
        "kind": "testStarted",
        "instant": {"since1970": 123},
        "messages": [],
        "testID": "SomeValidTestID/testFunc()"
      }
      """)
    #expect(Event(decoding: event) == nil)
  }
}
#endif
