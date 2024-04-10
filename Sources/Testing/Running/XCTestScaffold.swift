//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_XCTEST_SCAFFOLDING && canImport(XCTest)
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
        error = TimeoutError(timeLimit: TimeValue(timeLimitComponents))
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
/// ## See Also
///
/// - <doc:TemporaryGettingStarted>
#if SWIFT_PM_SUPPORTS_SWIFT_TESTING
@available(*, deprecated, message: "This version of Swift Package Manager supports running swift-testing tests directly. This type will be removed in a future release.")
#else
@available(swift, deprecated: 100000.0, message: "This type is provided temporarily to aid in integrating the testing library with existing tools such as Swift Package Manager. It will be removed in a future release.")
#endif
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
  @available(*, deprecated, message: "This version of Swift Package Manager supports running swift-testing tests directly. This function has no effect and will be removed in a future release.")
#else
  @available(swift, deprecated: 100000.0, message: "This function is provided temporarily to aid in integrating the testing library with existing tools such as Swift Package Manager. It will be removed in a future release.")
#endif
  public static func runAllTests(hostedBy testCase: XCTestCase, _ functionName: String = #function) async {
#if SWIFT_PM_SUPPORTS_SWIFT_TESTING
    let message = Event.ConsoleOutputRecorder.warning(
      "This version of Swift Package Manager supports running swift-testing tests directly. Ignoring call to \(#function).",
      options: .for(.stderr)
    )
#if SWT_TARGET_OS_APPLE && !SWT_NO_FILE_IO
    try? FileHandle.stderr.write(message)
#else
    print(message)
#endif
#else
    let testCase = UncheckedSendable(rawValue: testCase)
#if SWT_TARGET_OS_APPLE
    let isProcessLaunchedByXcode = Environment.variable(named: "XCTestSessionIdentifier") != nil
#endif

    var configuration = Configuration()
    configuration.isParallelizationEnabled = false
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

#if !SWT_NO_EXIT_TESTS
    // Exit test handling.
    if let exitTest = ExitTest.find(withArguments: CommandLine.arguments()) {
      await exitTest()
      exit(EXIT_SUCCESS)
    }
    let typeName = String(reflecting: type(of: testCase.rawValue as Any))
    let functionName = if let parenIndex = functionName.lastIndex(of: "(") {
      functionName[..<parenIndex]
    } else {
      functionName[...]
    }
    let testIdentifier = "\(typeName)/\(functionName)"
    configuration.exitTestHandler = ExitTest.handlerForSwiftPM(forXCTestCaseIdentifiedBy: testIdentifier)
#endif

    var options = Event.ConsoleOutputRecorder.Options()
#if !SWT_NO_FILE_IO
    options = .for(.stderr)
#endif
    options.isVerbose = (Environment.flag(named: "SWT_VERBOSE_OUTPUT") == true)

    await runTests(options: options, configuration: configuration)
#endif
  }
}
#endif
