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

struct ExpectedIssuesTests {
  @Test(arguments: ExpectedIssuesVariant.allCases)
  fileprivate func `matched issues are not reported upstream`(variant: ExpectedIssuesVariant) async {
    let reportedIssues = await variant.run(
      body: { Issue.record("hello") },
      matchers: [
        { #expect($0.comments == ["hello"]) }
      ]
    )

    #expect(reportedIssues.isEmpty)
  }

  @Test(
    arguments: ExpectedIssuesVariant.allCases,
    [
      ["a", "b", "c"],
      ["a", "c", "b"],
      ["b", "a", "c"],
      ["b", "c", "a"],
      ["c", "b", "a"],
      ["c", "a", "b"],
    ]
  )
  fileprivate func `matchers do not need to be in the same order that issues were reported in`(
    variant: ExpectedIssuesVariant,
    issueComments: [Comment]
  ) async {
    let reportedIssues = await variant.run(
      body: {
        issueComments
          .forEach { Issue.record($0) }
      },
      matchers: [
        { #expect($0.comments == ["a"]) },
        { #expect($0.comments == ["b"]) },
        { #expect($0.comments == ["c"]) },
      ]
    )

    #expect(reportedIssues.isEmpty)
  }

  @Test(arguments: ExpectedIssuesVariant.allCases)
  fileprivate func `unmatched issues are reported upstream`(variant: ExpectedIssuesVariant) async throws {
    let reportedIssues = await variant.run(
      body: { Issue.record("hello") },
      matchers: [
        { #expect($0.comments == ["goodbye"]) }
      ]
    )

    #expect(reportedIssues.count == 2)
    #expect(reportedIssues.contains { issue in
      issue.comments == ["hello"]
    })
    #expect(reportedIssues.contains { issue in
      issue.comments == ["Matcher 0 did not match any issue."]
    })
  }

  @Test(arguments: ExpectedIssuesVariant.allCases)
  fileprivate func `reports an issue when no issues are reported`(variant: ExpectedIssuesVariant) async throws {
    let sourceLocation = #Testing::sourceLocation
    let reportedIssues = await variant.run(
      sourceLocation: sourceLocation,
      body: { },
      matchers: [
        { _ in }
      ]
    )

    #expect(reportedIssues.count == 2)
    #expect(reportedIssues.contains { issue in
      issue.comments == ["Expected 1 issue(s) to be recorded, but got 0."]
      && issue.sourceLocation == sourceLocation
    })
    #expect(reportedIssues.contains { issue in
      issue.comments == ["Matcher 0 did not match any issue."]
      && issue.sourceLocation == sourceLocation
    })
  }

  @Test(arguments: ExpectedIssuesVariant.allCases)
  fileprivate func `reports an issue when there are more matchers than reported issues`(variant: ExpectedIssuesVariant) async throws {
    let issueLocation = #Testing::sourceLocation
    let sourceLocation = #Testing::sourceLocation
    let reportedIssues = await variant.run(
      sourceLocation: sourceLocation,
      body: {
        Issue.record("hello", sourceLocation: issueLocation)
      },
      matchers: [
        { _ in },
        { _ in },
      ]
    )

    #expect(reportedIssues.count == 2)
    #expect(reportedIssues.contains { issue in
      issue.comments == ["Expected 2 issue(s) to be recorded, but got 1."]
      && issue.sourceLocation == sourceLocation
    })
    #expect(reportedIssues.contains { issue in
      issue.comments == ["Unused matcher 1 matches issues [Issue recorded at \(issueLocation) (error): hello], which matched with other matchers."]
      && issue.sourceLocation == sourceLocation
    })
  }

  @Test(arguments: ExpectedIssuesVariant.allCases)
  fileprivate func `Allows multiple issues to map to multiple matcher, so long as all matchers/issues are claimed`(variant: ExpectedIssuesVariant) async throws {
    let reportedIssues = await variant.run(
      body: {
        Issue.record("hello")
        Issue.record("goodbye")
      },
      matchers: [
        { _ in },
        { _ in },
      ]
    )

    #expect(reportedIssues.isEmpty)
  }

  @Test(arguments: ExpectedIssuesVariant.allCases)
  fileprivate func `matches issues to the closest possible matcher`(variant: ExpectedIssuesVariant) async throws {
    let reportedIssues = await variant.run(
      body: {
        Issue.record("hello")
        Issue.record("hello2")
        Issue.record("goodbye")
      },
      matchers: [
        { #expect($0.comments == ["goodbye"]) },
        { _ in },
        { issue in
          #expect(issue.comments.contains { (comment: Comment) in
            String(describing: comment).contains("hello")
          })
        },
      ]
    )

    #expect(reportedIssues.isEmpty)
  }

  @Test(arguments: ExpectedIssuesVariant.allCases)
  fileprivate func `records issue when multiple issues only map to a single matcher`(variant: ExpectedIssuesVariant) async throws {
    let issue1Location = #Testing::sourceLocation
    let issue2Location = #Testing::sourceLocation
    let reportedIssues = await variant.run(
      body: {
        Issue.record("hello", sourceLocation: issue1Location)
        Issue.record("hello", sourceLocation: issue2Location)
      },
      matchers: [
        { #expect($0.comments == ["goodbye"]) },
        { _ in },
      ]
    )

    #expect(reportedIssues.count == 3)

    #expect(reportedIssues.contains { issue in
      issue.comments == ["Matcher 0 did not match any issue."]
    })

    let issueText = [
      "Issue recorded at \(issue1Location) (error): hello",
      "Issue recorded at \(issue2Location) (error): hello",
    ].joined(separator: ", ")
    let commentText = "Matches matchers [1], but too many issues ([\(issueText)]) match those matchers."

    #expect(reportedIssues.contains { issue in
      issue.comments == [
        "hello",
        Comment(rawValue: commentText),
      ] && issue.sourceLocation == issue1Location
    })
    #expect(reportedIssues.contains { issue in
      issue.comments == [
        "hello",
        Comment(rawValue: commentText),
      ] && issue.sourceLocation == issue2Location
    })
  }

  @Test(arguments: ExpectedIssuesVariant.allCases)
  fileprivate func `when an issue maps to multiple matchers`(variant: ExpectedIssuesVariant) async throws {
    let issue1Location = #Testing::sourceLocation
    let issue2Location = #Testing::sourceLocation

    let expectedIssuesSourceLocation = #Testing::sourceLocation()
    let reportedIssues = await variant.run(
      sourceLocation: expectedIssuesSourceLocation,
      body: {
        Issue.record("hello", sourceLocation: issue1Location)
        Issue.record("goodbye", sourceLocation: issue2Location)
      },
      matchers: [
        { #expect($0.comments == ["hello"]) },
        { #expect($0.comments == ["hello"]) },
      ]
    )

    #expect(reportedIssues.count == 2)

    #expect(reportedIssues.contains { issue in
      issue.comments == ["goodbye"]
    })

    // Report the unmatched issue.
    let issueText = "[Issue recorded at \(issue1Location) (error): hello]"
    let commentText = Comment(
      rawValue: "Unused matcher 1 matches issues \(issueText), which matched with other matchers."
    )
    #expect(reportedIssues.contains { issue in
      issue.comments == [commentText]
      && issue.sourceLocation == expectedIssuesSourceLocation
    })
  }

  @Test(arguments: ExpectedIssuesVariant.allCases)
  fileprivate func `Transitive issue/matcher groups are correctly detected`(variant: ExpectedIssuesVariant) async throws {
    let reportedIssues = await variant.run(
      body: {
        Issue.record("a")
        Issue.record("b")
        Issue.record("c")
      },
      matchers: [
        { #expect($0.comments == ["a"] || $0.comments == ["b"]) },
        { #expect($0.comments == ["a"] || $0.comments == ["c"]) },
        { #expect($0.comments == ["c"] || $0.comments == ["b"]) },
      ]
    )

    #expect(reportedIssues.isEmpty)
  }
}

private enum ExpectedIssuesVariant: CaseIterable {
  case synchronous
  case asynchronous

  func run(
    sourceLocation: SourceLocation = #Testing::sourceLocation,
    body: @Sendable () throws -> Void,
    matchers: [@Sendable (Issue) throws -> Void]
  ) async -> [Issue] {
    switch self {
    case .synchronous:
      return withIssueCapturing {
        withExpectedIssue(
          sourceLocation: sourceLocation,
          body,
          matching: matchers
        )
      }
    case .asynchronous:
      @Sendable func forceAsync() async {}
      return await withIssueCapturing {
        await withExpectedIssue(
          sourceLocation: sourceLocation,
          {
            try body()
            await forceAsync()
          },
          matching: matchers
        )
      }
    }
  }
}
