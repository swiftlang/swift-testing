//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Testing
import TestingUtilities

struct IssueCapturingTests {
  // See `TestingTests.IssueCapturingTests` for more thorough and comprehensive
  // tests of `withIssueCapturing`.

  // Disambiguation is required because `withIssueCapturing` has package level
  // access in `Testing`.
  @Test func `withIssueCapturing synchronous`() {
    let issues = TestingUtilities.withIssueCapturing {
      Issue.record("oh no")
    }

    #expect(issues.count == 1)
    #expect(issues.last?.comments == ["oh no"])
    #expect(issues.last?.isFailure == true)
  }

  @Test func `withIssueCapturing asynchronous`() async {
    func forceAsync() async -> Void {}

    let issues = await TestingUtilities.withIssueCapturing {
      Issue.record("oh no")
      await forceAsync()
    }

    #expect(issues.count == 1)
    #expect(issues.last?.comments == ["oh no"])
    #expect(issues.last?.isFailure == true)
  }

  @Test func `withIssueCapturing synchronous, using matching`() async {
    let outerIssues = TestingUtilities.withIssueCapturing {
      _ = TestingUtilities.withIssueCapturing {
        Issue.record("oh no")
        Issue.record("oh yes")
      } matching: { issue in issue.comments.contains("oh yes") }
    }

    #expect(outerIssues.count == 1)
    #expect(outerIssues.last?.comments == ["oh no"])
    #expect(outerIssues.last?.isFailure == true)
  }

  @Test func `withIssueCapturing asynchronous, using matching`() async {
    func forceAsync() async -> Void {}


    let outerIssues = await TestingUtilities.withIssueCapturing {
      _ = await TestingUtilities.withIssueCapturing {
        Issue.record("oh no")
        Issue.record("oh yes")
        await forceAsync()
      } matching: { issue in issue.comments.contains("oh yes") }
    }

    #expect(outerIssues.count == 1)
    #expect(outerIssues.last?.comments == ["oh no"])
    #expect(outerIssues.last?.isFailure == true)
  }
}
