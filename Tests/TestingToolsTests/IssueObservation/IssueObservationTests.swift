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
import TestingTools

struct IssueObservationTests {
  // See `TestingTests.IssueObservationTests` for more thorough and
  // comprehensive tests of `withIssueObservation`.

  // Disambiguation is required because `withIssueObservation` has package level
  // access in `Testing`.
  @Test func `withIssueObservation synchronous`() {
    let issues = TestingTools.withIssueCapturing {
      let observedIssues = TestingTools.withIssueObservation {
        Issue.record("oh no")
      }

      #expect(observedIssues.count == 1)
      #expect(observedIssues.last?.comments == ["oh no"])
      #expect(observedIssues.last?.isFailure == true)
    }

    // If `withIssueObservation` didn't work, then `withIssueCapturing` would
    // have recorded more than 1 issue.

    #expect(issues.count == 1)
    #expect(issues.last?.comments == ["oh no"])
    #expect(issues.last?.isFailure == true)
  }

  @Test func `withIssueObservation asynchronous`() async {
    func forceAsync() async -> Void {}

    let issues = await TestingTools.withIssueCapturing {
      await forceAsync()
      let observedIssues = TestingTools.withIssueObservation {
        Issue.record("oh no")
      }
      #expect(observedIssues.count == 1)
      #expect(observedIssues.last?.comments == ["oh no"])
      #expect(observedIssues.last?.isFailure == true)
    }

    // If `withIssueObservation` didn't work, then `withIssueCapturing` would
    // have recorded more than 1 issue.

    #expect(issues.count == 1)
    #expect(issues.last?.comments == ["oh no"])
    #expect(issues.last?.isFailure == true)
  }
}
