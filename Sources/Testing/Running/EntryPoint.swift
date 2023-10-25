//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_implementationOnly import TestingInternals

#if !SWT_TARGET_OS_APPLE
/// The entry point to the testing library used by Swift Package Manager.
///
/// - Returns: The result of invoking the testing library. The type of this
///   value is subject to change.
///
/// This function examines the command-line arguments to the current process
/// and then invokes available tests in the current process.
///
/// - Warning: This function is used by Swift Package Manager. Do not call it
///   directly.
@_spi(SwiftPackageManagerSupport)
public func __swiftPMEntryPoint() async -> CInt {
  let args = CommandLine.arguments()
  // We do not use --dump-tests-json to handle test list requests. If that
  // argument is passed, just exit early.
  if args.contains("--dump-tests-json") {
    return EXIT_SUCCESS
  }

  @Locked var exitCode = EXIT_SUCCESS
  await runTests { event, _ in
    if case let .issueRecorded(issue) = event.kind, !issue.isKnown {
      $exitCode.withLock { exitCode in
        exitCode = EXIT_FAILURE
      }
    }
  }
  return exitCode
}
#endif

/// The common implementation of `__swiftPMEntryPoint()` and
/// ``XCTestScaffold/runAllTests(hostedBy:)``.
///
/// - Parameters:
///   - testIDs: The test IDs to run. If `nil`, all tests are run.
///   - tags: The tags to filter by (only tests with one or more of these tags
///     will be run.)
///   - eventHandler: An event handler to invoke after events are written to
///     the standard error stream.
func runTests(identifiedBy testIDs: [Test.ID]? = nil, taggedWith tags: Set<Tag>? = nil, eventHandler: @escaping Event.Handler = { _, _ in }) async {
  let eventRecorder = Event.Recorder(options: .forStandardError) { string in
    let stderr = swt_stderr()
    fputs(string, stderr)
    fflush(stderr)
  }

  var configuration = Configuration()
  configuration.isParallelizationEnabled = false
  configuration.eventHandler = { event, context in
    eventRecorder.record(event, in: context)
    eventHandler(event, context)
  }
  
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

  let runner = await Runner(configuration: configuration)
  await runner.run()
}

// MARK: - Command-line interface options

extension [Event.Recorder.Option] {
  /// The set of options to use when writing to the standard error stream.
  static var forStandardError: Self {
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
