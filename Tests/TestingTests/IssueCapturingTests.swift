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
#if canImport(Synchronization)
private import Synchronization
#endif

struct IssueCapturingTests {
  @Test func `captureIssues sync does not report issues`() async {
    let capturedIssues = Allocated(Mutex([Issue]()))

    let reportedIssues = await runTestAndRecordIssues {
      let issues = captureIssues {
        Issue.record("")
      }
      capturedIssues.value.withLock { $0 = issues }
    }

    #expect(reportedIssues.isEmpty)

    capturedIssues.value.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
    }
  }

  @Test func `captureIssues async does not report issues`() async {
    @Sendable func forceAsync() async {}

    let capturedIssues = Allocated(Mutex([Issue]()))

    let reportedIssues = await runTestAndRecordIssues {
      let issues = await captureIssues {
        Issue.record("")
        await forceAsync()
      }
      capturedIssues.value.withLock { $0 = issues }
    }

    #expect(reportedIssues.isEmpty)

    capturedIssues.value.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
    }
  }

  @Test func `observeIssues sync does report issues`() async {
    let capturedIssues = Allocated(Mutex([Issue]()))

    let reportedIssues = await runTestAndRecordIssues {
      let issues = observeIssues {
        Issue.record("")
      }
      capturedIssues.value.withLock { $0 = issues }
    }

    #expect(reportedIssues.count == 1)
    #expect(reportedIssues.last?.isKnown == false)
    #expect(reportedIssues.last?.isFailure == true)

    capturedIssues.value.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
    }
  }

  @Test func `observeIssues async does report issues`() async {
    @Sendable func forceAsync() async {}

    let capturedIssues = Allocated(Mutex([Issue]()))

    let reportedIssues = await runTestAndRecordIssues {
      let issues = await observeIssues {
        Issue.record("")
        await forceAsync()
      }
      capturedIssues.value.withLock { $0 = issues }
    }

    #expect(reportedIssues.count == 1)
    #expect(reportedIssues.last?.isKnown == false)
    #expect(reportedIssues.last?.isFailure == true)

    capturedIssues.value.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
    }
  }

  @Test func `observeIssues reports and sets isKnown correctly`() async {
    struct MyError: Error {}

    let observedIssues = Allocated(Mutex([Issue]()))

    let reportedIssues = await runTestAndRecordIssues {
      let issues = observeIssues {
        throw MyError()
      }
      observedIssues.value.withLock { $0 = issues }
    }

    #expect(reportedIssues.count == 1)
    #expect(reportedIssues.last?.isKnown == false)
    #expect(reportedIssues.last?.isFailure == true)

    observedIssues.value.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
    }
  }

  @Test func `observeIssues recorded with comment`() async {
    let observedIssues = Allocated(Mutex([Issue]()))

    let reportedIssues = await runTestAndRecordIssues {
      let issues = observeIssues {
        Issue.record("Issue Comment")
      }
      observedIssues.value.withLock { $0 = issues }
    }

    #expect(reportedIssues.count == 1)
    #expect(reportedIssues.last?.isKnown == false)
    #expect(reportedIssues.last?.isFailure == true)
    #expect(reportedIssues.last?.comments == ["Issue Comment"])
    #expect(reportedIssues.last?.knownIssueContext == nil)

    observedIssues.value.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
      #expect(issues.last?.knownIssueContext == nil)
    }
  }

  @Test func `nesting observeIssues inside captureIssues`() async {
    let capturedIssues = Allocated(Mutex([Issue]()))
    let observedIssues = Allocated(Mutex([Issue]()))

    let reportedIssues = await runTestAndRecordIssues {
      let issues = captureIssues {
        let issues = observeIssues {
          Issue.record("Issue Comment")
        }
        observedIssues.value.withLock { $0 = issues }
      }
      capturedIssues.value.withLock { $0 = issues }
    }

    #expect(reportedIssues.isEmpty)

    capturedIssues.value.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
      #expect(issues.last?.comments == ["Issue Comment"])
      #expect(issues.last?.knownIssueContext == nil)
    }

    observedIssues.value.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
      #expect(issues.last?.comments == ["Issue Comment"])
      #expect(issues.last?.knownIssueContext == nil)
    }
  }

  @Test func `nesting captureIssues inside observeIssues`() async {
    let capturedIssues = Mutex([Issue]())
    let observedIssues = Mutex([Issue]())

    let reportedIssues = await runTestAndRecordIssues {
      let issues = observeIssues {
        let issues = captureIssues {
          Issue.record("Issue Comment")
        }
        capturedIssues.withLock { $0 = issues }
      }
      observedIssues.withLock { $0 = issues }
    }

    #expect(reportedIssues.isEmpty)

    capturedIssues.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
      #expect(issues.last?.comments == ["Issue Comment"])
    }

    observedIssues.withLock { issues in
      #expect(issues.isEmpty)
    }
  }

  @Test func `nesting withKnownIssue inside observeIssues, when an issue is recorded`() async {
    let observedIssues = Mutex([Issue]())

    let reportedIssues = await runTestAndRecordIssues {
      let issues = observeIssues {
        withKnownIssue("known issue scope") {
          Issue.record("Issue Comment")
        }
      }
      observedIssues.withLock { $0 = issues }
    }

    #expect(reportedIssues.count == 1)
    #expect(reportedIssues.last?.isFailure == false)
    #expect(reportedIssues.last?.comments == ["Issue Comment"])
    #expect(reportedIssues.last?.knownIssueContext?.comment == "known issue scope")

    observedIssues.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isFailure == false)
      #expect(issues.last?.comments == ["Issue Comment"])
      #expect(issues.last?.knownIssueContext?.comment == "known issue scope")
    }
  }

  @Test func `nesting withKnownIssue inside observeIssues, when an issue is recorded, but not matched to the parent scope`() async {
    let observedIssues = Mutex([Issue]())

    let reportedIssues = await runTestAndRecordIssues {
      let issues = observeIssues {
        withKnownIssue("known issue scope") {
          Issue.record("Issue Comment")
        } matching: { _ in false }
      }
      observedIssues.withLock { $0 = issues }
    }

    #expect(reportedIssues.count == 2)
    #expect(reportedIssues.contains(where: { issue in
      issue.isFailure == true &&
      issue.comments == ["Issue Comment"] &&
      issue.knownIssueContext == nil
    }))
    #expect(reportedIssues.contains(where: { issue in
      issue.isFailure == true &&
      issue.comments == ["known issue scope"] &&
      issue.knownIssueContext == nil
    }))

    observedIssues.withLock { issues in
      #expect(issues.count == 2)
      #expect(issues.contains(where: { issue in
        issue.isFailure == true &&
        issue.comments == ["Issue Comment"] &&
        issue.knownIssueContext == nil
      }))
      #expect(issues.contains(where: { issue in
        issue.isFailure == true &&
        issue.comments == ["known issue scope"] &&
        issue.knownIssueContext == nil
      }))
    }
  }

  @Test func `nesting withKnownIssue inside observeIssues, when no issue is recorded`() async {
    let observedIssues = Mutex([Issue]())

    let reportedIssues = await runTestAndRecordIssues {
      let issues = observeIssues {
        withKnownIssue("known issue scope") {
        }
      }
      observedIssues.withLock { $0 = issues }
    }

    #expect(reportedIssues.count == 1)
    #expect(reportedIssues.last?.isFailure == true)
    #expect(reportedIssues.last?.comments == ["known issue scope"])
    #expect(reportedIssues.last?.knownIssueContext == nil)

    observedIssues.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isFailure == true)
      #expect(issues.last?.comments == ["known issue scope"])
      #expect(issues.last?.knownIssueContext == nil)
    }
  }

  @Test func `nesting withKnownIssue inside captureIssues, when an issue is recorded`() async {
    let capturedIssues = Mutex([Issue]())

    let reportedIssues = await runTestAndRecordIssues {
      let issues = captureIssues {
        withKnownIssue("known issue scope") {
          Issue.record("Issue Comment")
        }
      }
      capturedIssues.withLock { $0 = issues }
    }

    #expect(reportedIssues.isEmpty)

    capturedIssues.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isFailure == false)
      #expect(issues.last?.comments == ["Issue Comment"])
      #expect(issues.last?.knownIssueContext?.comment == "known issue scope")
    }
  }

  @Test func `nesting withKnownIssue inside captureIssues, when an issue is recorded, but not matched to the parent scope`() async {
    let capturedIssues = Mutex([Issue]())

    let reportedIssues = await runTestAndRecordIssues {
      let issues = captureIssues {
        withKnownIssue("known issue scope") {
          Issue.record("Issue Comment")
        } matching: { _ in false }
      }
      capturedIssues.withLock { $0 = issues }
    }

    #expect(reportedIssues.isEmpty)

    capturedIssues.withLock { issues in
      #expect(issues.count == 2)
      #expect(issues.contains(where: { issue in
        issue.isFailure == true &&
        issue.comments == ["Issue Comment"] &&
        issue.knownIssueContext == nil
      }))
      #expect(issues.contains(where: { issue in
        issue.isFailure == true &&
        issue.comments == ["known issue scope"] &&
        issue.knownIssueContext == nil
      }))
    }
  }

  @Test func `nesting withKnownIssue inside captureIssues, when no issue is recorded`() async {
    let capturedIssues = Mutex([Issue]())

    let reportedIssues = await runTestAndRecordIssues {
      let issues = captureIssues {
        withKnownIssue("known issue scope") {
        }
      }
      capturedIssues.withLock { $0 = issues }
    }

    #expect(reportedIssues.isEmpty)

    capturedIssues.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
      #expect(issues.last?.comments == ["known issue scope"])
      #expect(issues.last?.knownIssueContext == nil)
    }
  }

  @Test func `nesting captureIssues inside withKnownIssue`() async {
    let capturedIssues = Mutex([Issue]())

    let reportedIssues = await runTestAndRecordIssues {
      withKnownIssue("known issue scope") {
        let issues = captureIssues {
          Issue.record("Issue Comment")
        }
        capturedIssues.withLock { $0 = issues }
      }
    }

    // It doesn't even see the reported issue, and thus reports that no expected
    // issue was recorded.
    #expect(reportedIssues.count == 1)
    #expect(reportedIssues.last?.isKnown == false)
    #expect(reportedIssues.last?.isFailure == true)
    #expect(reportedIssues.last?.comments == ["known issue scope"])
    #expect(reportedIssues.last?.knownIssueContext == nil)

    capturedIssues.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
      #expect(issues.last?.comments == ["Issue Comment"])
      #expect(issues.last?.knownIssueContext == nil)
    }
  }

  @Test func `nesting observeIssues inside withKnownIssue`() async {
    let observedIssues = Mutex([Issue]())

    let reportedIssues = await runTestAndRecordIssues {
      withKnownIssue("known issue scope") {
        let issues = observeIssues {
          Issue.record("Issue Comment")
        }
        observedIssues.withLock { $0 = issues }
      }
    }

    // It does see the reported issue as a known issue
    #expect(reportedIssues.count == 1)
    #expect(reportedIssues.last?.isKnown == true)
    #expect(reportedIssues.last?.isFailure == false)
    #expect(reportedIssues.last?.comments == ["Issue Comment"])
    #expect(reportedIssues.last?.knownIssueContext?.comment == "known issue scope")

    // inside of `observeIssues`, this is something we want to report back to
    // the testing library as an unexpected issue.
    // However, once it passes into withKnownIssue, that'll transform this into
    // a known issue.
    observedIssues.withLock { issues in
      #expect(issues.count == 1)
      #expect(issues.last?.isKnown == false)
      #expect(issues.last?.isFailure == true)
      #expect(issues.last?.comments == ["Issue Comment"])
      #expect(issues.last?.knownIssueContext == nil)
    }
  }
}
