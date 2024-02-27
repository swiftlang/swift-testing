//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import TestingInternals

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
@_disfavoredOverload public func __swiftPMEntryPoint() async -> CInt {
  let exitCode = Locked(rawValue: EXIT_SUCCESS)

  do {
    let args = CommandLine.arguments()
    if args.count == 2 && args[1] == "--list-tests" {
      for testID in await listTestsForSwiftPM(Test.all) {
        print(testID)
      }
    } else {
      var configuration = try configurationForSwiftPMEntryPoint(withArguments: args)
      let oldEventHandler = configuration.eventHandler
      configuration.eventHandler = { event, context in
        if case let .issueRecorded(issue) = event.kind, !issue.isKnown {
          exitCode.withLock { exitCode in
            exitCode = EXIT_FAILURE
          }
        }
        oldEventHandler(event, context)
      }

      var options = [Event.ConsoleOutputRecorder.Option]()
#if !SWT_NO_FILE_IO
      options += .for(.stderr)
#endif
      if args.contains("--verbose") {
        options.append(.useVerboseOutput)
      }

      await runTests(options: options, configuration: configuration)
    }
  } catch {
#if !SWT_NO_FILE_IO
    FileHandle.stderr.withUnsafeCFILEHandle { stderr in
      fputs(String(describing: error), stderr)
      fflush(stderr)
    }
#endif

    exitCode.withLock { exitCode in
      exitCode = EXIT_FAILURE
    }
  }

  return exitCode.rawValue
}

/// The entry point to the testing library used by Swift Package Manager.
///
/// This function examines the command-line arguments to the current process
/// and then invokes available tests in the current process. When the tests
/// complete, the process is terminated. If tests were successful, an exit code
/// of `EXIT_SUCCESS` is used; otherwise, a (possibly platform-specific) value
/// such as `EXIT_FAILURE` is used instead.
///
/// - Warning: This function is used by Swift Package Manager. Do not call it
///   directly.
public func __swiftPMEntryPoint() async -> Never {
  let exitCode: CInt = await __swiftPMEntryPoint()
  exit(exitCode)
}

// MARK: -

/// List all of the given tests in the "specifier" format used by Swift Package
/// Manager.
///
/// - Parameters:
///   - tests: The tests to list.
///
/// - Returns: An array of strings representing the IDs of `tests`.
func listTestsForSwiftPM(_ tests: some Sequence<Test>) -> [String] {
  // Filter out hidden tests and test suites. Hidden tests should not generally
  // be presented to the user, and suites (XCTestCase classes) are not included
  // in the equivalent XCTest-based output.
  let tests = tests.lazy
    .filter { !$0.isSuite }
    .filter { !$0.isHidden }

  // Group tests by the name components of the tests' IDs. If the name
  // components of two tests' IDs are ambiguous, present their source locations
  // to disambiguate.
  return Dictionary(
    grouping: tests.lazy.map(\.id),
    by: \.nameComponents
  ).values.lazy
    .map { ($0, isAmbiguous: $0.count > 1) }
    .flatMap { testIDs, isAmbiguous in
      testIDs.lazy
        .map { testID in
          if !isAmbiguous, testID.sourceLocation != nil {
            return testID.parent ?? testID
          }
          return testID
        }
    }.map(String.init(describing:))
    .sorted(by: <)
}

/// Get an instance of ``Configuration`` given a sequence of command-line
/// arguments passed from Swift Package Manager.
///
/// - Parameters:
///   - args: The command-line arguments to interpret.
///
/// - Returns: An instance of ``Configuration``. Note that the caller is
///   responsible for setting this instance's ``Configuration/eventHandler``
///   property.
///
/// - Throws: If an argument is invalid, such as a malformed regular expression.
///
/// This function generally assumes that Swift Package Manager has already
/// validated the passed arguments.
func configurationForSwiftPMEntryPoint(withArguments args: [String]) throws -> Configuration {
  var configuration = Configuration()
  configuration.isParallelizationEnabled = false

  // Do not consider the executable path AKA argv[0].
  let args = args.dropFirst()

  // Parallelization (on by default)
  configuration.isParallelizationEnabled = true
  if args.contains("--no-parallel") {
    configuration.isParallelizationEnabled = false
  }

#if !SWT_NO_FILE_IO
  // XML output
  if let xunitOutputIndex = args.firstIndex(of: "--xunit-output"), xunitOutputIndex < args.endIndex {
    let xunitOutputPath = args[args.index(after: xunitOutputIndex)]

    // Open the XML file for writing.
    let file = try FileHandle(forWritingAtPath: xunitOutputPath)

    // Set up the XML recorder.
    let xmlRecorder = Event.JUnitXMLRecorder { string in
      file.withUnsafeCFILEHandle { file in
        fputs(string, file)
        fflush(file)
      }
    }

    let oldEventHandler = configuration.eventHandler
    configuration.eventHandler = { event, context in
      _ = xmlRecorder.record(event, in: context)
      oldEventHandler(event, context)
    }
  }
#endif

  // Filtering
  // NOTE: Regex is not marked Sendable, but because the regexes we use are
  // constructed solely from a string, they are safe to send across isolation
  // boundaries.
  var filters = [Configuration.TestFilter]()
  if let filterArgIndex = args.firstIndex(of: "--filter"), filterArgIndex < args.endIndex {
    guard #available(_regexAPI, *) else {
      throw _EntryPointError.featureUnavailable("The '--filter' option is not supported on this OS version.")
    }

    let filterArg = args[args.index(after: filterArgIndex)]
    let regex = try UncheckedSendable(rawValue: Regex(filterArg))
    let filter = Configuration.TestFilter(membership: .including) { test in
      let id = String(describing: test.id)
      return id.contains(regex.rawValue)
    }
    filters.append(filter)
  }
  if let skipArgIndex = args.firstIndex(of: "--skip"), skipArgIndex < args.endIndex {
    guard #available(_regexAPI, *) else {
      throw _EntryPointError.featureUnavailable("The '--skip' option is not supported on this OS version.")
    }

    let skipArg = args[args.index(after: skipArgIndex)]
    let regex = try UncheckedSendable(rawValue: Regex(skipArg))
    let filter = Configuration.TestFilter(membership: .excluding) { test in
      let id = String(describing: test.id)
      return id.contains(regex.rawValue)
    }
    filters.append(filter)
  }

  configuration.testFilter = filters.reduce(.unfiltered) { $0.combining(with: $1) }

  // Set up the iteration policy for the test run.
  var repetitionPolicy: Configuration.RepetitionPolicy = .once
  var hadExplicitRepetitionCount = false
  if let repetitionsIndex = args.firstIndex(of: "--repetitions"), repetitionsIndex < args.endIndex,
     let repetitionCount = Int(args[args.index(after: repetitionsIndex)]), repetitionCount > 0 {
    repetitionPolicy.maximumIterationCount = repetitionCount
    hadExplicitRepetitionCount = true
  }
  if let repeatUntilIndex = args.firstIndex(of: "--repeat-until"), repeatUntilIndex < args.endIndex {
    let repeatUntil = args[args.index(after: repeatUntilIndex)].lowercased()
    switch repeatUntil {
    case "pass":
      repetitionPolicy.continuationCondition = .whileIssueRecorded
    case "fail":
      repetitionPolicy.continuationCondition = .untilIssueRecorded
    default:
      throw _EntryPointError.invalidArgument("--repeat-until", value: repeatUntil)
    }
    if !hadExplicitRepetitionCount {
      // The caller wants to repeat until a condition is met, but didn't say how
      // many times to repeat, so assume they meant "forever".
      repetitionPolicy.maximumIterationCount = .max
    }
  }
  configuration.repetitionPolicy = repetitionPolicy

  return configuration
}

/// The common implementation of ``swiftPMEntryPoint()`` and
/// ``XCTestScaffold/runAllTests(hostedBy:)``.
///
/// - Parameters:
///   - options: Options to pass when configuring the console output recorder.
///   - configuration: The configuration to use for running.
func runTests(options: [Event.ConsoleOutputRecorder.Option], configuration: Configuration) async {
  let eventRecorder = Event.ConsoleOutputRecorder(options: options) { string in
#if !SWT_NO_FILE_IO
    FileHandle.stderr.withUnsafeCFILEHandle { stderr in
      fputs(string, stderr)
      fflush(stderr)
    }
#endif
  }

  var configuration = configuration
  let oldEventHandler = configuration.eventHandler
  configuration.eventHandler = { event, context in
    eventRecorder.record(event, in: context)
    oldEventHandler(event, context)
  }

  let runner = await Runner(configuration: configuration)
  await runner.run()
}

// MARK: - Command-line interface options

extension [Event.ConsoleOutputRecorder.Option] {
#if !SWT_NO_FILE_IO
  /// The set of options to use when writing to the standard error stream.
  static func `for`(_ fileHandle: borrowing FileHandle) -> Self {
    var result = Self()

    let useANSIEscapeCodes = _fileHandleSupportsANSIEscapeCodes(fileHandle)
    if useANSIEscapeCodes {
      result.append(.useANSIEscapeCodes)
      if _terminalSupports256ColorANSIEscapeCodes {
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

    // Load tag colors from user/package preferences on disk.
    if let tagColors = try? loadTagColors() {
      result.append(.useTagColors(tagColors))
    }

    return result
  }

  /// Whether or not the current process's standard error stream is capable of
  /// accepting and rendering ANSI escape codes.
  private static func _fileHandleSupportsANSIEscapeCodes(_ fileHandle: borrowing FileHandle) -> Bool {
    // Respect the NO_COLOR environment variable. SEE: https://www.no-color.org
    if let noColor = Environment.variable(named: "NO_COLOR"), !noColor.isEmpty {
      return false
    }

    // Determine if this file handle appears to write to a Terminal window
    // capable of accepting ANSI escape codes.
    if fileHandle.isTTY {
      return true
    }

    // If the file handle is a pipe, assume the other end is using it to forward
    // output from this process to its own stderr file. This is how `swift test`
    // invokes the testing library, for example.
    if fileHandle.isPipe {
      return true
    }

    return false
  }

  /// Whether or not the system terminal claims to support 256-color ANSI escape
  /// codes.
  private static var _terminalSupports256ColorANSIEscapeCodes: Bool {
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
#endif
}

// MARK: - Error reporting

/// A type describing an error encountered in the entry point.
private enum _EntryPointError: Error {
  /// A feature is unavailable.
  ///
  /// - Parameters:
  ///   - explanation: An explanation of the problem.
  case featureUnavailable(_ explanation: String)

  /// An argument was invalid.
  ///
  /// - Parameters:
  ///   - name: The name of the argument.
  ///   - value: The invalid value.
  case invalidArgument(_ name: String, value: String)
}

extension _EntryPointError: CustomStringConvertible {
  var description: String {
    switch self {
    case let .featureUnavailable(explanation):
      explanation
    case let .invalidArgument(name, value):
      #"Invalid value "\#(value)" for argument \#(name)"#
    }
  }
}
