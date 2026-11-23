//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type to contain the logic for processing expected issues, as recorded
/// using ``withExpectedIssue(sourceLocation:_:matching:)``.
private struct ExpectedIssuesProcessor: ~Copyable, ~Escapable {
  private typealias MatcherIndex = Int
  private typealias IssueIndex = Int

  private struct MatcherResult {
    let matcherIndex: MatcherIndex
    let issues: [Issue]

    var issueCount: Int { issues.count }
    var matches: Bool { issues.isEmpty }
  }

  private struct IndexedIssue: Hashable, Comparable {
    let index: IssueIndex
    var issue: Issue

    func hash(into hasher: inout Hasher) {
      hasher.combine(index)
    }

    static func == (lhs: IndexedIssue, rhs: IndexedIssue) -> Bool {
      lhs.index == rhs.index
    }

    static func < (lhs: IndexedIssue, rhs: IndexedIssue) -> Bool {
      lhs.index < rhs.index
    }
  }

  private let sourceLocation: SourceLocation
  private var recordedIssueIndices = Set<IssueIndex>()
  private var processedIssues = [IndexedIssue: [MatcherResult]]()
  private var issuesForMatcherIndex = [MatcherIndex: [IndexedIssue]]()

  /// Create a new ``ExpectedIssuesProcessor`` instance with the given
  /// sourceLocation.
  ///
  /// - Parameters:
  ///   - sourceLocation: The location where the `withExpectedIssues` call was
  ///     originally made.
  init(
    sourceLocation: borrowing SourceLocation
  ) {
    self.sourceLocation = sourceLocation
  }

  /// Process the list of recorded issues alongside the matchers to determine if
  /// every recorded issue was expected.
  ///
  /// - Parameters:
  ///   - issues: The list of recorded issues to process.
  ///   - matchers: The list of matchers to check each issue against.
  consuming func run(
    recordedIssues issues: [Issue],
    matchers: [@Sendable (Issue) throws -> Void]
  ) {
    checkForUnequalMatchersAndIssues(
      recordedIssueCount: issues.count,
      matcherCount: matchers.count
    )
    let indexedIssues = issues.enumerated().map(IndexedIssue.init)
    processedIssues = runMatchersAgainstIssues(
      issues: indexedIssues,
      matchers: matchers
    )

    filterOutAndRecordUnmatchedIssues()

    // Save this off to provide extra info to aid test authors in debugging
    // failed tests.
    let originalMatchedIssues = processedIssues

    issuesForMatcherIndex = mapPassingMatchersToIssues(
      matcherIndices: Array(matchers.indices),
    )

    if allIssuesMap1To1WithMatchers() {
      return
    }

    recordUnusedMatchers()

    filterMatchersWithOnlyOneIssue()

    detectIssueGroups()

    detectIssuesWithOtherwiseClaimedMatchers(
      originalMatchedIssues: originalMatchedIssues
    )

    detectUnusedButOtherwiseMatchedMatchers(
      originalMatchedIssues: originalMatchedIssues
    )
  }

  /// Record a separate issue as part of processing, not as part of one of the
  /// issues being processed.
  ///
  /// - Parameters:
  ///   - comment: The comment associated with the issue.
  private func recordIndependentIssue(_ comment: Comment) {
    Issue(
      kind: .unconditional,
      comments: [
        comment
      ],
      sourceContext: SourceContext(
        backtrace: .current(),
        sourceLocation: sourceLocation
      )
    ).record()
  }

  /// Detect if there are an unequal amount of matchers and issues, and record
  /// an issue if that is the case.
  ///
  /// - Parameters:
  ///   - recordedIssueCount: The number of recorded issues.
  ///   - matcherCount: The number of matchers.
  private func checkForUnequalMatchersAndIssues(
    recordedIssueCount: Int,
    matcherCount: Int
  ) {
    if recordedIssueCount != matcherCount {
      recordIndependentIssue(
        "Expected \(matcherCount) issue(s) to be recorded, but got \(recordedIssueCount)."
      )
    }
  }

  /// Run every matcher against the recorded issue, returning the mapping of
  /// issues to the results of that run.
  ///
  /// - Parameters:
  ///   - issues: The list of issues, indexed as per the ordering of `issues` in
  ///     ``run(recordedIssues:matchers:)``.
  ///   - matchers: The list of matchers to run.
  ///
  /// - Returns: A mapping of the indexed issues to the results of running the
  ///   matchers against that issue.
  private func runMatchersAgainstIssues(
    issues: [IndexedIssue],
    matchers: [@Sendable (Issue) throws -> Void]
  ) -> [IndexedIssue: [MatcherResult]] {
    issues.reduce(
      into: [IndexedIssue: [MatcherResult]]()
    ) { partialResult, issue in
      partialResult[issue] = matchers.enumerated()
        .map { (index, matcher) in
          return MatcherResult(
            matcherIndex: index,
            issues: withIssueCapturing {
              try matcher(issue.issue)
            }
          )
        }
    }
  }

  private mutating func filterOutAndRecordUnmatchedIssues() {
    for (issue, matchResults) in processedIssues {
      if matchResults.contains(where: { $0.matches }) {
        processedIssues[issue] = matchResults.filter { $0.matches }
      } else {
        processedIssues.removeValue(forKey: issue)

        var issue = issue
        let commentsToAppend = processedIssues
          .flatMap { processedIssue -> [Comment] in
            return matchResults
              .flatMap { (matchResult: MatcherResult) -> [Comment] in
                matchResult.issues.flatMap { issue -> [Comment] in
                  return issue.comments.map { comment -> Comment in
                    "From matcher \(matchResult.matcherIndex): \(comment)"
                  }
                }
              }
          }
        issue.issue.comments.append(contentsOf: commentsToAppend)
        issue.issue.record()
      }
    }
  }

  /// Create a mapping of matchers to the issues which matched them.
  ///
  /// - Parameters:
  ///   - matcherIndices: The indices of the `matchers` array passed in to
  ///     ``run(recordedIssues:matchers:)``.
  ///
  /// - Returns: A mapping of matchers to the issues which matched them.
  private func mapPassingMatchersToIssues(
    matcherIndices: [MatcherIndex],
  ) -> [MatcherIndex: [IndexedIssue]] {
    // processedIssues now only contains issues that have matched with at least
    // one matcher.
    var issuesForMatcherIndex = [MatcherIndex: [IndexedIssue]]()
    for index in matcherIndices {
      issuesForMatcherIndex[index] = []
    }
    for (issue, matchResults) in processedIssues {
      for result in matchResults {
        var existing = issuesForMatcherIndex[result.matcherIndex] ?? []
        existing.append(issue)
        issuesForMatcherIndex[result.matcherIndex] = existing
      }
    }
    return issuesForMatcherIndex
  }

  /// Detect if every issue cleanly maps 1-1 with a single matcher.
  /// This is used so we can early-exit processing in this happy-path case.
  ///
  /// - Returns: Whether all issues cleanly mapped 1-1 with every matcher.
  private func allIssuesMap1To1WithMatchers() -> Bool {
    issuesForMatcherIndex.allSatisfy({ $0.value.count == 1 })
    && processedIssues.allSatisfy({ $0.value.count == 1 })
  }

  /// Record an issue for each matcher that did not match even any issue.
  private mutating func recordUnusedMatchers() {
    for (matcherIndex, issues) in issuesForMatcherIndex where issues.isEmpty {
      recordIndependentIssue("Matcher \(matcherIndex) did not match any issue.")
      issuesForMatcherIndex.removeValue(forKey: matcherIndex)
    }
  }

  /// Remove the matched issue and matcher from the list of issues and matchers
  /// used in further processing
  private mutating func removeMatchedIssue(
    _ issue: IndexedIssue,
    matcherIndex: MatcherIndex
  ) {
    issuesForMatcherIndex.removeValue(forKey: matcherIndex)
    for (matcherIndex, issues) in issuesForMatcherIndex {
      issuesForMatcherIndex[matcherIndex] = issues.filter { $0 != issue }
    }
    for (issue, results) in processedIssues {
      processedIssues[issue] = results.filter { $0.matcherIndex != matcherIndex }
    }
    processedIssues.removeValue(forKey: issue)
  }

  /// Detects and filters out from further processing matchers that cleanly map
  /// to only a single issue.
  private mutating func filterMatchersWithOnlyOneIssue() {
    while issuesForMatcherIndex.isEmpty == false {
      var madeChange = false
      for matcherIndex in issuesForMatcherIndex.keys.sorted() {
        if let issues = issuesForMatcherIndex[matcherIndex],
            issues.count == 1,
           let issue = issues.first {
          removeMatchedIssue(issue, matcherIndex: matcherIndex)
          madeChange = true
        }
      }
      if madeChange == false { break }
    }
  }

  /// Detects issue groups, and ensures that the number of matched issues
  /// agrees with the number of matchers for this issue group.
  ///
  /// An issue group is a subset of issue/matchers that all mutually match.
  /// For example, a set of 2 issues and matchers that both fit with one
  /// another:
  /// ```swift
  /// withExpectedIssue {
  ///   Issue.record("a")
  ///   Issue.record("b")
  /// } matching: {
  ///   #expect($0.comments == ["a"] || $0.comments == ["b"]
  /// } _: {
  ///   #expect($0.comments == ["a"] || $0.comments == ["b"]
  /// }
  /// ```
  ///
  /// Or a set of issues and matchers that transitively fit together:
  /// ```swift
  /// withExpectedIssue {
  ///   Issue.record("a")
  ///   Issue.record("b")
  ///   Issue.record("c")
  /// } matching: {
  ///   #expect($0.comments == ["a"] || $0.comments == ["b"]
  /// } _: {
  ///   #expect($0.comments == ["b"] || $0.comments == ["c"]
  /// } _: {
  ///   #expect($0.comments == ["c"] || $0.comments == ["a"]
  /// }
  /// ```
  ///
  /// When issue groups contain unequal numbers of issues and matchers, the
  /// issues will be re-emited with comments adding details about all of the
  /// the issues and matchers in that issue group.
  private mutating func detectIssueGroups() {
    for unmatchedIssue in processedIssues.keys.sorted() {
      guard let results = processedIssues[unmatchedIssue] else { continue }
      let matcherIndices = Set(results.map { $0.matcherIndex })
      let matcherSet = processedIssues
        .compactMap({ (key: IndexedIssue, value: [MatcherResult]) -> Set<MatcherIndex>? in
          let additionalIndices = Set(value.map { $0.matcherIndex })
          if additionalIndices.isDisjoint(with: matcherIndices) == false {
            return additionalIndices
          }
          return nil
        })
        .reduce(matcherIndices) { partialResult, newSet in
          partialResult.union(newSet)
        }
      let issuesForMatchers = Set(matcherSet.flatMap { matcherIndex in
        issuesForMatcherIndex[matcherIndex] ?? []
      })

      func handleUnequalIssueGroup(_ commentGenerator: ([Issue]) -> Comment) {
        for indexedIssue in issuesForMatchers where recordedIssueIndices.contains(indexedIssue.index) == false {
          var issue = indexedIssue.issue
          let matchingIssues = issuesForMatchers
            .map { $0.issue }
            .sorted(by: {
              guard let sl0 = $0.sourceLocation, let sl1 = $1.sourceLocation else {
                return true
              }
              return sl0 < sl1
            })
          issue.comments.append(commentGenerator(matchingIssues))
          issue.record()
          recordedIssueIndices.insert(indexedIssue.index)
        }
      }

      if issuesForMatchers.count == matcherSet.count {
        for issue in issuesForMatchers {
          processedIssues.removeValue(forKey: issue)
        }
        for matcherIndex in matcherSet {
          removeMatchedIssue(unmatchedIssue, matcherIndex: matcherIndex)
        }
      } else if issuesForMatchers.count > matcherSet.count {
        handleUnequalIssueGroup { matchingIssues in
          "Matches matchers \(matcherSet), but too many issues (\(matchingIssues)) match those matchers."
        }
      } else {
        handleUnequalIssueGroup { matchingIssues in
          "Matches matchers \(matcherSet), but too few issues (\(matchingIssues)) match those matchers."
        }
      }
    }
  }

  /// Detects when an Issue that originally did match at least 1 matcher now
  /// no longer has an associated matcher. This can happen when 2 issues match
  /// to the same matcher, but 1 of the issues is assigned to that matcher.
  /// Information about what happened is appended as a comment to the original
  /// issue, which is then re-emitted.
  ///
  /// - Parameters:
  ///   - originalMatchedIssues: The list of IndexedIssue to matcher results,
  ///     before any subsequent processing was performed. This is used to
  ///     provide data to the test author about the other issues that shared
  ///     a matcher with this issue.
  private mutating func detectIssuesWithOtherwiseClaimedMatchers(
    originalMatchedIssues: [IndexedIssue: [MatcherResult]]
  ) {
    for (indexedIssue, matchResults) in processedIssues where matchResults.isEmpty {
      let originalMatcherIndices = originalMatchedIssues[indexedIssue]?
        .map { $0.matcherIndex }
        .sorted() ?? []

      var issue = indexedIssue.issue
      for index in originalMatcherIndices {
        issue.comments.append("Matched matcher \(index), but matcher \(index) was claimed by another issue.")
        recordedIssueIndices.insert(indexedIssue.index)
      }
      issue.record()
    }
  }

  /// Records an issue for each matcher that originally did match at least one
  /// issue, but some other matcher was claimed as the matcher for the issue.
  ///
  /// - Parameters:
  ///   - originalMatchedIssues: The list of IndexedIssue to matcher results,
  ///     before any subsequent processing was performed. This is used to
  ///     provide data to the test author about the other issues that matched
  ///     this matcher.
  private func detectUnusedButOtherwiseMatchedMatchers(
    originalMatchedIssues: [IndexedIssue: [MatcherResult]]
  ) {
    for (matcherIndex, issuesList) in issuesForMatcherIndex where issuesList.isEmpty {
      let otherIssues = originalMatchedIssues.filter { (key: IndexedIssue, value: [MatcherResult]) in
        value.contains(where: { $0.matcherIndex == matcherIndex })
      }.map { $0.key.issue }
      recordIndependentIssue(
        "Unused matcher \(matcherIndex) matches issues \(otherIssues), which matched with other matchers."
      )
    }
  }
}

/// Invoke a function that is expected to record at least one issue during its
/// execution. Expected issues will not be sent to the rest of the testing
/// library.
///
/// - Parameters:
///   - body: The function to invoke.
///   - issueMatchers: The functions to invoke when an issue occurs that is used
///     to determine if the issue is expected, utilizing `#expect` and
///     `#require` to indicate that the issue is expected.
///
/// Library authors use this function to validate that code correctly records
/// the expected issues. For every expected issue, there must be an equivalent
/// matcher closure that captures that issue. Matcher closures may be evaluated
/// multiple times, and the Testing Library will attempt to match recorded
/// issues to the most appropriate matcher.
///
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
package func withExpectedIssue(
  sourceLocation: SourceLocation,
  _ body: () throws -> Void,
  matching issueMatchers: [@Sendable (Issue) throws -> Void]
) {
  let issues = withIssueCapturing(body)
  ExpectedIssuesProcessor(sourceLocation: sourceLocation)
    .run(recordedIssues: issues, matchers: issueMatchers)
}

/// Invoke a function that is expected to record at least one issue during its
/// execution. Expected issues will not be sent to the rest of the testing
/// library.
///
/// - Parameters:
///   - body: The function to invoke.
///   - issueMatchers: The functions to invoke when an issue occurs that is used
///     to determine if the issue is expected, utilizing `#expect` and
///     `#require` to indicate that the issue is expected.
///
/// Library authors use this function to validate that code correctly records
/// the expected issues. For every expected issue, there must be an equivalent
/// matcher closure that captures that issue. Matcher closures may be evaluated
/// multiple times, and the Testing Library will attempt to match recorded
/// issues to the most appropriate matcher.
///
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
package func withExpectedIssue(
  sourceLocation: SourceLocation,
  _ body: sending @isolated(any) () async throws -> Void,
  matching issueMatchers: [@Sendable (Issue) throws -> Void]
) async {
  let issues = await withIssueCapturing(body)
  ExpectedIssuesProcessor(sourceLocation: sourceLocation)
    .run(recordedIssues: issues, matchers: issueMatchers)
}
