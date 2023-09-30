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
@testable @_spi(ExperimentalEventHandling) @_spi(ExperimentalTestRunning) import Testing

final class KnownIssueTests: XCTestCase {
  func testIssueIsKnownPropertyIsSetCorrectly() async {
    struct MyError: Error {}

    let issueRecorded = expectation(description: "Issue recorded")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      issueRecorded.fulfill()

      XCTAssertTrue(issue.isKnown)
    }

    await Test {
      withKnownIssue {
        throw MyError()
      }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded], timeout: 0.0)
  }

  func testKnownIssueWithComment() async {
    let issueRecorded = expectation(description: "Issue recorded")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      issueRecorded.fulfill()

      guard case .knownIssueNotRecorded = issue.kind else {
        return
      }

      XCTAssertEqual(issue.comments.first, "With Known Issue Comment")
      XCTAssertFalse(issue.isKnown)
    }

    await Test {
      withKnownIssue("With Known Issue Comment") { }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded], timeout: 0.0)
  }

  func testIssueIsKnownPropertyIsSetCorrectlyWithCustomIssueMatcher() async {
    struct MyError: Error {}

    let issueRecorded = expectation(description: "Issue recorded")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      issueRecorded.fulfill()

      XCTAssertTrue(issue.isKnown)
    }

    await Test {
      try! withKnownIssue {
        throw MyError()
      } matching: { issue in
        issue.error is MyError
      }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded], timeout: 0.0)
  }

  func testUnexpectedErrorRecordsTwoIssues() async {
    // If an error is thrown that doesn't match with the issue matcher, then
    // that's one issue; a second issue is that the *known* issue never
    // happened.
    struct MyExpectedError: Error {}
    struct MyUnexpectedError: Error {}

    let issueRecorded = expectation(description: "Issue recorded")
    issueRecorded.expectedFulfillmentCount = 2
    let errorRecorded = expectation(description: "Error recorded")
    let knownIssueNotRecorded = expectation(description: "Known issue not recorded")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      issueRecorded.fulfill()

      XCTAssertFalse(issue.isKnown)
      if case .knownIssueNotRecorded = issue.kind {
        knownIssueNotRecorded.fulfill()
      } else if issue.error != nil {
        errorRecorded.fulfill()
      }
    }

    await Test {
      try withKnownIssue {
        throw MyUnexpectedError()
      } matching: { issue in
        return issue.error is MyExpectedError
      }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded, errorRecorded, knownIssueNotRecorded], timeout: 0.0)
  }

  func testKnownIssueWithExpectCall() async {
    let issueRecorded = expectation(description: "Issue recorded")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind,
            case .expectationFailed = issue.kind else {
        return
      }
      issueRecorded.fulfill()

      XCTAssertTrue(issue.isKnown)
    }

    await Test {
      withKnownIssue {
        #expect(Bool(false))
      } matching: { issue in
        if case .expectationFailed = issue.kind {
          return true
        }
        return false
      }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded], timeout: 0.0)
  }

  func testKnownIssueWithExpectCallAndCondition() async {
    let issueRecorded = expectation(description: "Issue recorded")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind,
            case .expectationFailed = issue.kind else {
        return
      }
      issueRecorded.fulfill()

      XCTAssertTrue(issue.isKnown)
    }

    await Test {
      withKnownIssue {
        #expect(Bool(false))
      } when: {
        true
      }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded], timeout: 0.0)
  }

  func testAsyncKnownIssueWithExpectCall() async {
    struct MyError: Error {}

    let issueRecorded = expectation(description: "Issue recorded")
    issueRecorded.expectedFulfillmentCount = 2

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      issueRecorded.fulfill()

      XCTAssertTrue(issue.isKnown)
    }

    await Test {
      await withKnownIssue { () async throws in
        #expect(Bool(false))
        throw MyError()
      }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded], timeout: 0.0)
  }

  func testAsyncKnownIssueWithExpectCallAndCondition() async {
    struct MyError: Error {}

    let issueRecorded = expectation(description: "Issue recorded")
    issueRecorded.expectedFulfillmentCount = 2

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      issueRecorded.fulfill()

      XCTAssertTrue(issue.isKnown)
    }

    await Test {
      try await withKnownIssue { () async throws in
        #expect(Bool(false))
        throw MyError()
      } when: {
        true
      }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded], timeout: 0.0)
  }

#if !SWT_NO_UNSTRUCTURED_TASKS
  func testKnownIssueOnDetachedTask() async {
    let issueRecorded = expectation(description: "Issue recorded")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      issueRecorded.fulfill()
      XCTAssertTrue(issue.isKnown)
    }

    await Test {
      await Task.detached {
        withKnownIssue {
          #expect(Bool(false))
        }
      }.value
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded], timeout: 0.0)
  }
#endif

  func testKnownIssueWithFalsePrecondition() async {
    let issueRecorded = expectation(description: "Issue recorded")
    let issueMatcherCalled = expectation(description: "Issue matcher called")
    issueMatcherCalled.isInverted = true

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case .issueRecorded = event.kind else {
        return
      }
      issueRecorded.fulfill()
    }

    await Test {
      withKnownIssue {
        Issue.record()
      } when: {
        false
      } matching: { _ in
        issueMatcherCalled.fulfill()
        return true
      }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded, issueMatcherCalled], timeout: 0.0)
  }

  func testAsyncKnownIssueWithFalsePrecondition() async {
    struct MyError: Error {}

    let issueRecorded = expectation(description: "Issue recorded")
    let issueMatcherCalled = expectation(description: "Issue matcher called")
    issueMatcherCalled.isInverted = true

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case .issueRecorded = event.kind else {
        return
      }
      issueRecorded.fulfill()
    }

    await Test {
      await withKnownIssue { () async in
        Issue.record()
      } when: {
        false
      } matching: { _ in
        issueMatcherCalled.fulfill()
        return true
      }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded, issueMatcherCalled], timeout: 0.0)
  }

  func testKnownIssueThatDoesNotAlwaysOccur() async {
    struct MyError: Error {}

    let issueRecorded = expectation(description: "Issue recorded")
    issueRecorded.expectedFulfillmentCount = 2
    let knownIssueNotRecorded = expectation(description: "Known issue not recorded")
    knownIssueNotRecorded.isInverted = true

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case .knownIssueNotRecorded = issue.kind {
        knownIssueNotRecorded.fulfill()
      } else {
        issueRecorded.fulfill()
      }
    }

    await Test {
      withKnownIssue(isIntermittent: true) {}
      withKnownIssue(isIntermittent: true) {
        Issue.record()
        throw MyError()
      }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded, knownIssueNotRecorded], timeout: 0.0)
  }

  func testAsyncKnownIssueThatDoesNotAlwaysOccur() async {
    struct MyError: Error {}

    let issueRecorded = expectation(description: "Issue recorded")
    issueRecorded.expectedFulfillmentCount = 2
    let knownIssueNotRecorded = expectation(description: "Known issue not recorded")
    knownIssueNotRecorded.isInverted = true

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case .knownIssueNotRecorded = issue.kind {
        knownIssueNotRecorded.fulfill()
      } else {
        issueRecorded.fulfill()
      }
    }

    await Test {
      await withKnownIssue(isIntermittent: true) { () async in
      }
      await withKnownIssue(isIntermittent: true) { () async throws in
        Issue.record()
        throw MyError()
      }
    }.run(configuration: configuration)

    await fulfillment(of: [issueRecorded, knownIssueNotRecorded], timeout: 0.0)
  }
}
#endif
