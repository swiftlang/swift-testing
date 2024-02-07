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

<<<<<<< Updated upstream
      await runTests(configuration: configuration)
=======
      var options = [Event.ConsoleOutputRecorder.Option]()
#if !SWT_NO_FILE_IO
      options += .for(.standardError)
#endif
      if args.contains("--verbose") {
        options.append(.recordVerboseOutput)
      }

      await runTests(options: options, configuration: configuration)
>>>>>>> Stashed changes
    }
  } catch {
    File.standardError.withUnsafeFILEHandle { stderr in
      fputs(String(describing: error), stderr)
      fflush(stderr)
    }

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
    let file = try File.open(atPath: xunitOutputPath, mode: "wb")

    // Set up the XML recorder.
    let xmlRecorder = Event.JUnitXMLRecorder { string in
      file.withUnsafeFILEHandle { file in
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
    filters.append { test in
      let id = String(describing: test.id)
      return id.contains(regex.rawValue)
    }
  }
  if let skipArgIndex = args.firstIndex(of: "--skip"), skipArgIndex < args.endIndex {
    guard #available(_regexAPI, *) else {
      throw _EntryPointError.featureUnavailable("The '--skip' option is not supported on this OS version.")
    }

    let skipArg = args[args.index(after: skipArgIndex)]
    let regex = try UncheckedSendable(rawValue: Regex(skipArg))
    filters.append { test in
      let id = String(describing: test.id)
      return !id.contains(regex.rawValue)
    }
  }

  configuration.testFilter = { [filters] test in
    filters.allSatisfy { filter in
      filter(test)
    }
  }

  return configuration
}

/// The common implementation of ``swiftPMEntryPoint()`` and
/// ``XCTestScaffold/runAllTests(hostedBy:)``.
///
/// - Parameters:
///   - configuration: The configuration to use for running.
<<<<<<< Updated upstream
func runTests(configuration: Configuration) async {
  let eventRecorder = Event.ConsoleOutputRecorder(options: .forStandardError) { string in
    let stderr = swt_stderr()
    fputs(string, stderr)
    fflush(stderr)
=======
func runTests(options: [Event.ConsoleOutputRecorder.Option], configuration: Configuration) async {
  let eventRecorder = Event.ConsoleOutputRecorder(options: options) { string in
    File.standardError.withUnsafeFILEHandle { stderr in
      fputs(string, stderr)
      fflush(stderr)
    }
>>>>>>> Stashed changes
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

#if !SWT_NO_FILE_IO
extension [Event.ConsoleOutputRecorder.Option] {
  /// The set of options to use when writing to the standard error stream.
  static func `for`(_ file: borrowing File) -> Self {
    var result = Self()

    let useANSIEscapeCodes = file.supportsANSIEscapeCodes
    if useANSIEscapeCodes {
      result.append(.useANSIEscapeCodes)
      if terminalSupports256ColorANSIEscapeCodes {
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
}
#endif

// MARK: - Error reporting

/// A type describing an error encountered in the entry point.
private enum _EntryPointError: Error {
  /// A feature is unavailable.
  ///
  /// - Parameters:
  ///   - explanation: An explanation of the problem.
  case featureUnavailable(_ explanation: String)
}

extension _EntryPointError: CustomStringConvertible {
  var description: String {
    switch self {
    case let .featureUnavailable(explanation):
      explanation
    }
  }
}
