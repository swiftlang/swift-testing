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

func myFunction(_ first: () -> Void, closures: () -> Void...) { }

struct ExpectedIssuesTests {
  @Sendable func forceAsync() async {
    myFunction {
    } closures: {
    } _: {

    }

  }

  @Test func `sync does not report issues for matched issue`() {
    let reportedIssues = Testing.withIssueCapturing {
      withExpectedIssue {
        Issue.record("hello")
      } matching: {
        #expect($0.comments == ["hello"])
      }
    }

    #expect(reportedIssues.isEmpty)
  }

  @Test func `async does not report issues for matched issue`() async {
    let reportedIssues = await Testing.withIssueCapturing {
      await withExpectedIssue {
        Issue.record("hello")
        await forceAsync()
      } matching: {
        #expect($0.comments == ["hello"])
      }
    }

    #expect(reportedIssues.isEmpty)
  }
}
