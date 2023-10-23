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
@_implementationOnly import TestingInternals
import XCTest

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
  /// `swift test`. Instead, set the `SWT_SELECTED_TEST_IDS` environment
  /// variable to the ``Test/ID`` of the test that should run (or, if multiple
  /// tests should be run, their IDs separated by `";"`.)
  ///
  /// A test ID is composed of its module name, containing type name, and (if
  /// the test is a function rather than a suite), the name of the function
  /// including parentheses and any parameter labels. For example, given the
  /// following test functions in a module named `"MyTests"`:
  ///
  /// ```swift
  /// struct MySuite {
  ///   @Test func hello() { ... }
  ///   @Test(arguments: 0 ..< 10) func world(i: Int) { ... }
  /// }
  /// ```
  ///
  /// Their IDs are the strings `"MyTests/MySuite/hello()"` and
  /// `"MyTests/MySuite/world(i:)"` respectively, and they can be passed as the
  /// environment variable value
  /// `"MyTests/MySuite/hello();MyTests/MySuite/world(i:)"`.
  ///
  /// - Note: The module name of a test target in a Swift package is typically
  ///   the name of the test target.
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
  public static func runAllTests(hostedBy testCase: XCTestCase) async {
    let eventRecorder = Event.Recorder(options: .forStandardError) { string in
      let stderr = swt_stderr()
      fputs(string, stderr)
      fflush(stderr)
    }

#if SWT_TARGET_OS_APPLE
    let isProcessLaunchedByXcode = Environment.variable(named: "XCTestSessionIdentifier") != nil
#endif

    var configuration = Configuration()
    let testCase = UncheckedSendable(rawValue: testCase)
    configuration.isParallelizationEnabled = false
    configuration.eventHandler = { event, context in
      eventRecorder.record(event, in: context)

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

    // If the SWT_SELECTED_TEST_IDS environment variable is set, split it into
    // test IDs (separated by ";", test ID components separated by "/") and set
    // the configuration's test filter to match it.
    //
    // This environment variable stands in for `swift test --filter`.
    let testIDs: [Test.ID]? = Environment.variable(named: "SWT_SELECTED_TEST_IDS").map { testIDs in
      testIDs.split(separator: ";").map { testID in
        Test.ID(testID.split(separator: "/").map(String.init))
      }
    }
    if let testIDs {
      configuration.setTestFilter(toMatch: Set(testIDs))
    }

    let runner = await Runner(configuration: configuration)
    await runner.run()
  }
}

// MARK: -

extension [Event.Recorder.Option] {
  /// The set of options to use when writing to the standard error stream.
  fileprivate static var forStandardError: Self {
    var result = Self()

    let useANSIEscapeCodes = _standardErrorSupportsANSIEscapeCodes
    if useANSIEscapeCodes {
      result.append(.useANSIEscapeCodes)
      if _standardErrorSupports256ColorANSIEscapeCodes {
        result.append(.use256ColorANSIEscapeCodes)
      }
    }

#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
    // On macOS, if we are writing to a TTY (i.e. Terminal.app) and the SF Pro
    // font is installed, we can use SF Symbols characters in place of Unicode
    // pictographs. Other platforms do not generally have this font installed.
    // In case rendering with SF Symbols is causing problems (e.g. a third-party
    // terminal app is being used that doesn't support them), allow explicitly
    // toggling them with an environment variable.
    var useSFSymbols = false
    if let environmentVariable = Environment.flag(named: "SWT_SF_SYMBOLS_ENABLED") {
      useSFSymbols = environmentVariable
    } else if useANSIEscapeCodes {
      var statStruct = stat()
      useSFSymbols = (0 == stat("/Library/Fonts/SF-Pro.ttf", &statStruct))
    }
    if useSFSymbols {
      result.append(.useSFSymbols)
    }
#endif

    return result
  }

  /// Whether or not the current process's standard error stream is capable of
  /// accepting and rendering ANSI escape codes.
  private static var _standardErrorSupportsANSIEscapeCodes: Bool {
    // Respect the NO_COLOR environment variable. SEE: https://www.no-color.org
    if let noColor = Environment.variable(named: "NO_COLOR"), !noColor.isEmpty {
      return false
    }

    // Determine if stderr appears to write to a Terminal window capable of
    // accepting ANSI escape codes.
#if SWT_TARGET_OS_APPLE || os(Linux)
    // If stderr is a TTY and TERM is set, that's good enough for us.
    if 0 != isatty(STDERR_FILENO),
       let term = Environment.variable(named: "TERM"),
       !term.isEmpty && term != "dumb" {
      return true
    }
#elseif os(Windows)
    // If there is a console buffer associated with stderr, then it's a console.
    if let stderrHandle = GetStdHandle(STD_ERROR_HANDLE) {
      var screenBufferInfo = CONSOLE_SCREEN_BUFFER_INFO()
      if GetConsoleScreenBufferInfo(stderrHandle, &screenBufferInfo) {
        return true
      }
    }
#endif

    // If stderr is a pipe, assume the other end is using it to forward output
    // from this process to its own stderr file. This is how `swift test`
    // invokes the testing library, for example.
#if SWT_TARGET_OS_APPLE || os(Linux)
    var statStruct = stat()
    if 0 == fstat(STDERR_FILENO, &statStruct) && swt_S_ISFIFO(statStruct.st_mode) {
      return true
    }
#elseif os(Windows)
    if let stderrHandle = GetStdHandle(STD_ERROR_HANDLE), FILE_TYPE_PIPE == GetFileType(stderrHandle) {
      return true
    }
#endif

    return false
  }

  /// Whether or not the system terminal claims to support 256-color ANSI escape
  /// codes.
  private static var _standardErrorSupports256ColorANSIEscapeCodes: Bool {
#if SWT_TARGET_OS_APPLE || os(Linux)
    if let termVariable = Environment.variable(named: "TERM") {
      return strstr(termVariable, "256") != nil
    }
    return false
#elseif os(Windows)
    // Windows does not set the "TERM" variable, so assume it supports 256-color
    // ANSI escape codes.
    true
#endif
  }
}

#endif
