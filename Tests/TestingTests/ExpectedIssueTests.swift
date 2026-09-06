//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(XCTest)
import XCTest
@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

final class ExpectedIssueTests: XCTestCase {

  // MARK: - Basic capture

  func testExpectedIssueIsCaptured() async {
    // An issue recorded via Issue.record() inside withExpectedIssue should be
    // suppressed (not forwarded to the event handler) and returned to the caller.
    let unexpectedIssue = expectation(description: "unexpected issue recorded")
    unexpectedIssue.isInverted = true

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      if case .issueRecorded = event.kind {
        unexpectedIssue.fulfill()
      }
    }

    var capturedIssue: Issue?
    await Test {
      capturedIssue = withExpectedIssue {
        Issue.record("hello from expected issue")
      }
    }.run(configuration: configuration)

    // The issue must have been captured by withExpectedIssue.
    XCTAssertNotNil(capturedIssue)
    // And it must NOT have been forwarded to the event handler.
    await fulfillment(of: [unexpectedIssue], timeout: 0.0)
  }

  // MARK: - Issue content validation

  func testCapturedIssueContentIsAccessible() async {
    var capturedIssue: Issue?
    await Test {
      capturedIssue = withExpectedIssue {
        Issue.record("a specific message")
      }
    }.run(configuration: .init())

    XCTAssertNotNil(capturedIssue)
    XCTAssertEqual(capturedIssue?.comments, ["a specific message"])
    guard case .unconditional = capturedIssue?.kind else {
      XCTFail("Expected issue kind .unconditional")
      return
    }
  }

  // MARK: - Expectation failure issued correctly when body records no issue

  func testIssueRecordedWhenExpectedIssueDoesNotOccur() async {
    // If body records no issue, withExpectedIssue itself records a
    // .knownIssueNotRecorded issue so the test fails visibly.
    let missingIssueRecorded = expectation(description: "knownIssueNotRecorded issue recorded")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind,
            case .knownIssueNotRecorded = issue.kind else {
        return
      }
      missingIssueRecorded.fulfill()
    }

    await Test {
      withExpectedIssue {
        // body records nothing — withExpectedIssue should record a failure
      }
    }.run(configuration: configuration)

    await fulfillment(of: [missingIssueRecorded], timeout: 0.0)
  }

  // MARK: - isIntermittent suppresses missing-issue failure

  func testIntermittentExpectedIssueDoesNotFailWhenIssueAbsent() async {
    let unexpectedIssue = expectation(description: "unexpected issue recorded")
    unexpectedIssue.isInverted = true

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      if case .issueRecorded = event.kind {
        unexpectedIssue.fulfill()
      }
    }

    await Test {
      withExpectedIssue(isIntermittent: true) {
        // body records nothing — but isIntermittent: true means no failure
      }
    }.run(configuration: configuration)

    await fulfillment(of: [unexpectedIssue], timeout: 0.0)
  }

  // MARK: - Custom matcher

  func testCustomMatcherFiltersIssues() async {
    // Only issues whose comment contains "match me" should be captured;
    // all others should still be recorded normally.
    let unmatchedIssueRecorded = expectation(description: "unmatched issue forwarded")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else { return }
      if issue.comments.contains(where: { $0.rawValue.contains("do not match") }) {
        unmatchedIssueRecorded.fulfill()
      }
    }

    var capturedIssue: Issue?
    await Test {
      capturedIssue = withExpectedIssue(
        matching: { issue in
          issue.comments.contains { $0.rawValue.contains("match me") }
        }
      ) {
        Issue.record("match me")
        Issue.record("do not match")
      }
    }.run(configuration: configuration)

    // The matching issue should be captured.
    XCTAssertNotNil(capturedIssue)
    XCTAssertTrue(capturedIssue?.comments.first?.rawValue.contains("match me") == true)
    // The non-matching issue should have been forwarded to the event handler.
    await fulfillment(of: [unmatchedIssueRecorded], timeout: 0.0)
  }

  // MARK: - Only first matching issue is returned

  func testOnlyFirstMatchingIssueIsReturned() async {
    var capturedIssue: Issue?
    await Test {
      capturedIssue = withExpectedIssue {
        Issue.record("first")
        Issue.record("second")
      }
    }.run(configuration: .init())

    XCTAssertEqual(capturedIssue?.comments, ["first"])
  }

  // MARK: - Async version

  func testAsyncExpectedIssueIsCaptured() async {
    let unexpectedIssue = expectation(description: "unexpected issue recorded")
    unexpectedIssue.isInverted = true

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      if case .issueRecorded = event.kind {
        unexpectedIssue.fulfill()
      }
    }

    var capturedIssue: Issue?
    await Test {
      capturedIssue = await withExpectedIssue { () async in
        Issue.record("async expected issue")
      }
    }.run(configuration: configuration)

    XCTAssertNotNil(capturedIssue)
    await fulfillment(of: [unexpectedIssue], timeout: 0.0)
  }

  // MARK: - Thrown errors are matched

  func testThrownErrorIsMatchedByExpectedIssueScope() async {
    struct MyError: Error {}

    let unexpectedIssue = expectation(description: "unexpected issue recorded")
    unexpectedIssue.isInverted = true

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      if case .issueRecorded = event.kind {
        unexpectedIssue.fulfill()
      }
    }

    var capturedIssue: Issue?
    await Test {
      capturedIssue = withExpectedIssue(
        matching: { $0.error is MyError }
      ) {
        throw MyError()
      }
    }.run(configuration: configuration)

    XCTAssertNotNil(capturedIssue)
    XCTAssertTrue(capturedIssue?.error is MyError)
    await fulfillment(of: [unexpectedIssue], timeout: 0.0)
  }

  // MARK: - withExpectedIssue does not interfere with withKnownIssue

  func testExpectedIssueDoesNotInterfereWithKnownIssue() async {
    // A withKnownIssue inside withExpectedIssue: the known issue is handled by
    // KnownIssueScope first, so ExpectedIssueScope should NOT capture it.
    let knownIssueRecorded = expectation(description: "known issue recorded")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind,
            issue.isKnown else { return }
      knownIssueRecorded.fulfill()
    }

    var capturedIssue: Issue?
    await Test {
      capturedIssue = withExpectedIssue {
        withKnownIssue {
          Issue.record("this is the known issue")
        }
      }
    }.run(configuration: configuration)

    // The known issue was consumed by withKnownIssue, so withExpectedIssue
    // saw nothing and must report a missing-issue failure.
    // (capturedIssue should be nil and a knownIssueNotRecorded issue recorded.)
    XCTAssertNil(capturedIssue)
    // The known issue itself should still be forwarded with isKnown = true.
    await fulfillment(of: [knownIssueRecorded], timeout: 0.0)
  }

  // MARK: - #expect failure captured via ExpectationFailed kind

  func testExpectationFailureIsCaptured() async {
    var capturedIssue: Issue?
    await Test {
      capturedIssue = withExpectedIssue(
        matching: { issue in
          if case .expectationFailed = issue.kind { return true }
          return false
        }
      ) {
        #expect(Bool(false))
      }
    }.run(configuration: .init())

    XCTAssertNotNil(capturedIssue)
    guard case .expectationFailed = capturedIssue?.kind else {
      XCTFail("Expected .expectationFailed kind")
      return
    }
  }
}

// MARK: - Swift Testing style tests

@Suite("withExpectedIssue")
@_spi(Experimental)
struct WithExpectedIssueTests {

  @Test("Basic: issue is suppressed and returned")
  func basicIssueCapture() async {
    var configuration = Configuration()
    var issueWasForwarded = false
    configuration.eventHandler = { event, _ in
      if case .issueRecorded = event.kind { issueWasForwarded = true }
    }
    var capturedIssue: Issue?
    await Test {
      capturedIssue = withExpectedIssue {
        Issue.record("expected failure")
      }
    }.run(configuration: configuration)

    #expect(capturedIssue != nil)
    #expect(!issueWasForwarded)
    #expect(capturedIssue?.comments == ["expected failure"])
  }

  @Test("Async: issue is suppressed and returned")
  func asyncIssueCapture() async {
    var capturedIssue: Issue?
    await Test {
      capturedIssue = await withExpectedIssue { () async in
        Issue.record("async expected failure")
      }
    }.run(configuration: .init())

    #expect(capturedIssue != nil)
    #expect(capturedIssue?.comments == ["async expected failure"])
  }

  @Test("isIntermittent: no failure when body records no issue")
  func intermittentNoFailure() async {
    var configuration = Configuration()
    var issueWasForwarded = false
    configuration.eventHandler = { event, _ in
      if case .issueRecorded = event.kind { issueWasForwarded = true }
    }
    await Test {
      withExpectedIssue(isIntermittent: true) { /* no issue */ }
    }.run(configuration: configuration)

    #expect(!issueWasForwarded)
  }
}
#endif
