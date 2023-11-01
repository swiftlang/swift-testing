//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_XCTEST_SCAFFOLDING
private import TestingInternals
public import XCTest

#if SWT_TARGET_OS_APPLE
extension XCTSourceCodeContext {
  convenience init(_ sourceContext: SourceContext) {
    let addresses = sourceContext.backtrace?.addresses.map { $0 as NSNumber } ?? []
    let sourceLocation = sourceContext.sourceLocation.map { sourceLocation in
      XCTSourceCodeLocation(
        filePath: sourceLocation._filePath,
        lineNumber: sourceLocation.line
      )
    }
    self.init(callStackAddresses: addresses, location: sourceLocation)
  }
}

/// An error that is reported by ``XCTestScaffold`` when a test times out.
///
/// This type is not part of the public interface of the testing library.
struct TimeoutError: Error, CustomStringConvertible {
  /// The time limit exceeded by the test that timed out.
  var timeLimitComponents: (seconds: Int64, attoseconds: Int64)

  var description: String {
    let timeLimitDescription = descriptionOfTimeComponents(timeLimitComponents)
    return "Timed out after \(timeLimitDescription) seconds."
  }
}

extension XCTIssue {
  init(_ issue: Issue, processLaunchedByXcode: Bool) {
    var error = issue.error

    let issueType: XCTIssue.IssueType
    switch issue.kind {
    case .expectationFailed, .confirmationMiscounted:
      issueType = .assertionFailure
    case .errorCaught:
      issueType = .thrownError
    case let .timeLimitExceeded(timeLimitComponents: timeLimitComponents):
      issueType = .thrownError
      if error == nil {
        error = TimeoutError(timeLimitComponents: timeLimitComponents)
      }
    case .unconditional:
      issueType = .assertionFailure
    case .knownIssueNotRecorded:
      issueType = .unmatchedExpectedFailure
    case .apiMisused, .system:
      issueType = .system
    }

    // Only include the description of the specified issue in the value of this
    // XCTIssue's `compactDescription` property if the test runner process was
    // launched by Xcode. This can be confusing when examining the textual
    // output because it causes the description of the issue to be shown twice.
    // When the process is launched via Xcode, however, this is needed to show
    // a meaningful representation of the issue in Xcode's results UI.
    let compactDescription = processLaunchedByXcode ? String(describing: issue) : ""

    self.init(
      type: issueType,
      compactDescription: compactDescription,
      detailedDescription: nil,
      sourceCodeContext: XCTSourceCodeContext(issue.sourceContext),
      associatedError: error,
      attachments: []
    )
  }
}
#endif

// MARK: -

/// A type providing temporary tools for integrating the testing library and
/// the XCTest framework.
///
/// - Warning: This type is provided temporarily to aid in integrating the
///   testing library with existing tools such as Swift Package Manager. It
///   will be removed in a future release.
///
/// ## See Also
///
/// - <doc:TemporaryGettingStarted>
public enum XCTestScaffold: Sendable {
  /// Run all tests found in the current process and write output to the
  /// standard error stream.
  ///
  /// - Parameters:
  ///   - testCase: An `XCTestCase` instance that hosts tests implemented using
  ///     the testing library.
  ///
  /// Output from the testing library is written to the standard error stream.
  /// The format of the output is not meant to be machine-readable and is
  /// subject to change.
  ///
  /// - Warning: This function is provided temporarily to aid in integrating the
  ///   testing library with existing tools such as Swift Package Manager. It
  ///   will be removed in a future release.
  ///
  /// ### Filtering tests
  ///
  /// This function does not support the `--filter` argument passed to
  /// `swift test`. Instead, use one of several environment variables to control
  /// which tests run.
  ///
  /// #### Filtering by ID
  ///
  /// To run a specific test, set the `SWT_SELECTED_TEST_IDS` environment
  /// variable to the ``Test/ID`` of that test (or, if multiple tests should be
  /// run, their IDs separated by `";"`.)
  ///
  /// A test ID is composed of its module name, containing type name, and (if
  /// the test is a function rather than a suite), the name of the function
  /// including parentheses and any parameter labels. For example, given the
  /// following test functions in a module named `"FoodTruckTests"`:
  ///
  /// ```swift
  /// struct CashRegisterTests {
  ///   @Test func hasCash() { ... }
  ///   @Test(arguments: Card.allCases) func acceptsCard(card: Card) { ... }
  /// }
  /// ```
  ///
  /// Their IDs are the strings `"FoodTruckTests/CashRegisterTests/hasCash()"`
  /// and `"FoodTruckTests/CashRegisterTests/acceptsCard(card:)"` respectively,
  /// and they can be passed as the environment variable value
  /// `"FoodTruckTests/CashRegisterTests/hasCash();FoodTruckTests/CashRegisterTests/acceptsCard(card:)"`.
  ///
  /// - Note: The module name of a test target in a Swift package is typically
  ///   the name of the test target.
  ///
  /// #### Filtering by tag
  ///
  /// To run only those tests with a given ``Tag``, set the `SWT_SELECTED_TAGS`
  /// environment variable to the string value of that tag. Separate multiple
  /// tags with `";"`; tests with _any_ of the specified tags will be run. For
  /// example, to run all tests tagged `"critical"` _or_ ``Tag/red`` (or both),
  /// set the value of the `SWT_SELECTED_TAGS` environment variable to
  /// `"critical;red"`.
  ///
  /// ### Configuring output
  ///
  /// By default, this function uses
  /// [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code) to
  /// colorize output if the environment and platform support them. To disable
  /// colorized output, set the [`NO_COLOR`](https://www.no-color.org)
  /// environment variable.
  ///
  /// On macOS, if the SF&nbsp;Symbols app is installed, SF&nbsp;Symbols are
  /// assumed to be present in the font used for rendering within the Unicode
  /// Private Use Area. To disable the use of SF&nbsp;Symbols on macOS, set the
  /// `SWT_SF_SYMBOLS_ENABLED` environment variable to `"false"` or `"0"`.
  ///
  /// ## See Also
  ///
  /// - <doc:TemporaryGettingStarted>
#if SWIFT_PM_SUPPORTS_SWIFT_TESTING
  @available(*, deprecated, message: "This version of Swift Package Manager supports running swift-testing tests directly. This function has no effect.")
#endif
  public static func runAllTests(hostedBy testCase: XCTestCase) async {
#if SWIFT_PM_SUPPORTS_SWIFT_TESTING
    let message = warning("This version of Swift Package Manager supports running swift-testing tests directly. Ignoring call to \(#function).", options: .forStandardError)
#if SWT_TARGET_OS_APPLE
    let stderr = swt_stderr()
    fputs(message, stderr)
    fflush(stderr)
#else
    print(message)
#endif
#else
    let testCase = UncheckedSendable(rawValue: testCase)
#if SWT_TARGET_OS_APPLE
    let isProcessLaunchedByXcode = Environment.variable(named: "XCTestSessionIdentifier") != nil
#endif

    // If the SWT_SELECTED_TEST_IDS environment variable is set, split it into
    // test IDs (separated by ";", test ID components separated by "/") and set
    // the configuration's test filter to match it.
    //
    // This environment variable stands in for `swift test --filter`.
    let testIDs: [Test.ID]? = Environment.variable(named: "SWT_SELECTED_TEST_IDS").map { testIDs in
      testIDs.split(separator: ";", omittingEmptySubsequences: true).map { testID in
        Test.ID(testID.split(separator: "/", omittingEmptySubsequences: true).map(String.init))
      }
    }
    // If the SWT_SELECTED_TAGS environment variable is set, split it by ";"
    // (similar to test IDs above) and check if tests' tags overlap.
    let tags: Set<Tag>? = Environment.variable(named: "SWT_SELECTED_TAGS")
      .map { tags in
        tags
          .split(separator: ";", omittingEmptySubsequences: true)
          .map(String.init)
          .map(Tag.init(rawValue:))
      }.map(Set.init)

    var configuration = Configuration()
    configuration.isParallelizationEnabled = false
    if let testIDs {
      configuration.setTestFilter(toMatch: Set(testIDs))
    }
    if let tags {
      // Check if the test's tags intersect the set of selected tags. If there
      // was a previous filter function, it must also pass.
      let oldTestFilter = configuration.testFilter ?? { _ in true }
      configuration.testFilter = { test in
        !tags.isDisjoint(with: test.tags) && oldTestFilter(test)
      }
    }

    configuration.eventHandler = { event, context in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }

#if SWT_TARGET_OS_APPLE
      if issue.isKnown {
        XCTExpectFailure {
          testCase.rawValue.record(XCTIssue(issue, processLaunchedByXcode: isProcessLaunchedByXcode))
        }
      } else {
        testCase.rawValue.record(XCTIssue(issue, processLaunchedByXcode: isProcessLaunchedByXcode))
      }
#else
      // NOTE: XCTestCase.recordFailure(withDescription:inFile:atLine:expected:)
      // does not behave as it might appear. The `expected` argument determines
      // if the issue represents an assertion failure or a thrown error.
      if !issue.isKnown {
        testCase.rawValue.recordFailure(withDescription: String(describing: issue),
                                        inFile: issue.sourceLocation?._filePath ?? "<unknown>",
                                        atLine: issue.sourceLocation?.line ?? 0,
                                        expected: true)
      }
#endif
    }

    await runTests(configuration: configuration)
#endif
  }
}
#endif
