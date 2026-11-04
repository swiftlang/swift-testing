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

struct IssueRecordingTests {
  // See `TestingTests.IssueCapturingTests` for more thorough and comprehensive
  // tests of `withIssueCapturing`.

  // Disambiguation is required because `withIssueCapturing` has package level
  // access in `Testing`.
  @Test func `withIssueCapturing synchronous`() {
    let issues = TestingUtilities.withIssueCapturing {
      TestingUtilities.withIssueCapturing {
        Issue.record("oh no")
      }.forEach { _ = $0.record() }
    }

    #expect(issues.count == 1)
    #expect(issues.last?.comments == ["oh no"])
    #expect(issues.last?.isFailure == true)
  }
}
