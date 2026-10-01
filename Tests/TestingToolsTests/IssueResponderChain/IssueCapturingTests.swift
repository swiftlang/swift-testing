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

struct IssueCapturingTests {
  // See `TestingTests.IssueCapturingTests` for more thorough and comprehensive
  // tests of `captureIssues`.

  // Disambiguation is required because `captureIssues` has package level
  // access in `Testing`.
  @Test func `captureIssues synchronous`() {
    let issues = TestingTools.captureIssues {
      Issue.record("oh no")
    }

    #expect(issues.count == 1)
    #expect(issues.last?.comments == ["oh no"])
    #expect(issues.last?.isFailure == true)
  }

  @Test func `captureIssues asynchronous`() async {
    func forceAsync() async -> Void {}

    let issues = await TestingTools.captureIssues {
      Issue.record("oh no")
      await forceAsync()
    }

    #expect(issues.count == 1)
    #expect(issues.last?.comments == ["oh no"])
    #expect(issues.last?.isFailure == true)
  }
}
