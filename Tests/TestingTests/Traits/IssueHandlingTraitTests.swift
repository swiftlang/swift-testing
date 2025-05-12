//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

@Suite("IssueHandlingTrait Tests")
struct IssueHandlingTraitTests {
  @Test("Transforming an issue by appending a comment")
  func addComment() async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, context in
      guard case let .issueRecorded(issue) = event.kind, case .unconditional = issue.kind else {
        return
      }

      #expect(issue.comments == ["Foo", "Bar"])
    }

    let handler = IssueHandlingTrait.transformIssues { issue in
      var issue = issue
      issue.comments.append("Bar")
      return issue
    }

    await Test(handler) {
      Issue.record("Foo")
    }.run(configuration: configuration)
  }

  @Test("Suppressing an issue by returning `nil` from the transform closure")
  func suppressIssueUsingTransformer() async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, context in
      if case .issueRecorded = event.kind {
        Issue.record("Unexpected issue recorded event: \(event)")
      }
    }

    let handler = IssueHandlingTrait.transformIssues { _ in
      // Return nil to suppress the issue.
      nil
    }

    await Test(handler) {
      Issue.record("Foo")
    }.run(configuration: configuration)
  }

  @Test("Suppressing an issue by returning `false` from the filter closure")
  func filterIssue() async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, context in
      if case .issueRecorded = event.kind {
        Issue.record("Unexpected issue recorded event: \(event)")
      }
    }

    await Test(.filterIssues { _ in false }) {
      Issue.record("Foo")
    }.run(configuration: configuration)
  }

#if !SWT_NO_UNSTRUCTURED_TASKS
  @Test("Transforming an issue recorded from another trait on the test")
  func skipIssue() async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, context in
      guard case let .issueRecorded(issue) = event.kind, case .errorCaught = issue.kind else {
        return
      }

      #expect(issue.comments == ["Transformed!"])
    }

    struct MyError: Error {}

    try await confirmation("Transformer closure is called") { transformerCalled in
      let transformer: @Sendable (Issue) -> Issue? = { issue in
        defer {
          transformerCalled()
        }

        #expect(Test.Case.current == nil)

        var issue = issue
        issue.comments = ["Transformed!"]
        return issue
      }

      let test = Test(
        .enabled(if: try { throw MyError() }()),
        .transformIssues(transformer)
      ) {}

      // Use a detached task to intentionally clear task local values for the
      // current test and test case, since this test validates their value.
      await Task.detached { [configuration] in
        await test.run(configuration: configuration)
      }.value
    }
  }
#endif

  @Test("Accessing the current Test and Test.Case from a transformer closure")
  func currentTestAndCase() async throws {
    await confirmation("Transformer closure is called") { transformerCalled in
      let handler = IssueHandlingTrait.transformIssues { issue in
        defer {
          transformerCalled()
        }
        #expect(Test.current?.name == "fixture()")
        #expect(Test.Case.current != nil)
        return issue
      }

      var test = Test(handler) {
        Issue.record("Foo")
      }
      test.name = "fixture()"
      await test.run()
    }
  }

  @Test("Validate the relative execution order of multiple issue handling traits")
  func traitOrder() async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, context in
      guard case let .issueRecorded(issue) = event.kind, case .unconditional = issue.kind else {
        return
      }

      // Ordering is intentional
      #expect(issue.comments == ["Foo", "Bar", "Baz"])
    }

    let outerHandler = IssueHandlingTrait.transformIssues { issue in
      var issue = issue
      issue.comments.append("Baz")
      return issue
    }
    let innerHandler = IssueHandlingTrait.transformIssues { issue in
      var issue = issue
      issue.comments.append("Bar")
      return issue
    }

    await Test(outerHandler, innerHandler) {
      Issue.record("Foo")
    }.run(configuration: configuration)
  }

  @Test("Secondary issue recorded from a transformer closure")
  func issueRecordedFromClosure() async throws {
    await confirmation("Original issue recorded") { originalIssueRecorded in
      await confirmation("Secondary issue recorded") { secondaryIssueRecorded in
        var configuration = Configuration()
        configuration.eventHandler = { event, context in
          guard case let .issueRecorded(issue) = event.kind, case .unconditional = issue.kind else {
            return
          }

          if issue.comments.contains("Foo") {
            originalIssueRecorded()
          } else if issue.comments.contains("Something else") {
            secondaryIssueRecorded()
          } else {
            Issue.record("Unexpected issue recorded: \(issue)")
          }
        }

        let handler1 = IssueHandlingTrait.transformIssues { issue in
          return issue
        }
        let handler2 = IssueHandlingTrait.transformIssues { issue in
          Issue.record("Something else")
          return issue
        }
        let handler3 = IssueHandlingTrait.transformIssues { issue in
          // The "Something else" issue should not be passed to this closure.
          #expect(issue.comments.contains("Foo"))
          return issue
        }

        await Test(handler1, handler2, handler3) {
          Issue.record("Foo")
        }.run(configuration: configuration)
      }
    }
  }
}
