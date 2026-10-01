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

struct withIssueResponderTests {
  struct MyIssueResponder: IssueResponder {
    func respond(to issue: Issue) -> Issue? {
      var issue = issue
      issue.comments.append("Processed by MyIssueResponder")
      return issue
    }
  }

  // Disambiguation is required because `captureIssues` and
  // `withIssueResponder` are both package-level access in `Testing`.

  @Test func `withIssueResponder synchronous`() {
    let issues = TestingTools.captureIssues {
      TestingTools.withIssueResponder(MyIssueResponder()) {
        Issue.record("oh no")
        return ()
      }
    }

    #expect(issues.count == 1)
    #expect(issues.last?.comments == ["oh no", "Processed by MyIssueResponder"])
  }

  @Test func `withIssueResponder asynchronous`() async {
    func forceAsync() async -> Void {}

    let issues = await TestingTools.captureIssues {
      await TestingTools.withIssueResponder(MyIssueResponder()) {
        Issue.record("oh no")
        return await forceAsync()
      }
    }

    #expect(issues.count == 1)
    #expect(issues.last?.comments == ["oh no", "Processed by MyIssueResponder"])
  }
}
