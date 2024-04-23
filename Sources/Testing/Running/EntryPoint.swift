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

#if canImport(Foundation) && !SWT_NO_ABI_ENTRY_POINT
/// The type of the entry point to the testing library used by tools that want
/// to remain version-agnostic regarding the testing library.
///
/// - Parameters:
///   - argumentsJSON: A buffer to memory representing the JSON encoding of an
///     instance of `__CommandLineArguments_v0`. If `nil`, a new instance is
///     created from the command-line arguments to the current process.
///   - eventHandler: An event handler to which is passed a buffer to memory
///     representing each event and its context, as with ``Event/Handler``, but
///     encoded as JSON.
///
/// - Returns: The result of invoking the testing library. The type of this
///   value is subject to change.
///
/// This function examines the command-line arguments to the current process
/// and then invokes available tests in the current process.
///
/// - Warning: This function's signature and the structure of its JSON inputs
///   and outputs have not been finalized yet.
@_spi(ForToolsIntegrationOnly)
public typealias ABIEntryPoint_v0 = @Sendable (
  _ argumentsJSON: UnsafeRawBufferPointer?,
  _ eventHandler: @escaping @Sendable (_ eventAndContextJSON: UnsafeRawBufferPointer) -> Void
) async -> CInt

/// Get the entry point to the testing library used by tools that want to remain
/// version-agnostic regarding the testing library.
///
/// - Parameters:
///   - outEntryPoint: Uninitialized memory large enough to hold an instance of
///     ``ABIEntryPoint_v0``. On return, a pointer to an instance of that type
///     representing the ABI-stable entry point to the testing library. The
///     caller owns this memory and is responsible for deinitializing and
///     deallocating it when done.
///
/// This function can be used by tools that do not link directly to the testing
/// library and wish to invoke tests in a binary that has been loaded into the
/// current process. The function is emitted into the binary under the name
/// `"swt_copyABIEntryPoint_v0"` and can be dynamically looked up at runtime
/// using `dlsym()` or a platform equivalent.
///
/// The function stored at `outEntryPoint` can be thought of as equivalent to
/// `swift test --experimental-event-stream-output` except that, instead of
/// streaming events to a named pipe or file, it streams them to a callback.
///
/// - Warning: This function's signature and the structure of its JSON inputs
///   and outputs have not been finalized yet.
@_cdecl("swt_copyABIEntryPoint_v0")
@usableFromInline
func abiEntryPoint_v0(_ outEntryPoint: UnsafeMutableRawPointer) {
  outEntryPoint.initializeMemory(as: ABIEntryPoint_v0.self) { argumentsJSON, eventHandler in
    let args = try! argumentsJSON.map { argumentsJSON in
      try JSON.decode(__CommandLineArguments_v0.self, from: argumentsJSON)
    }

    let eventHandler = _eventHandlerForStreamingEvents_v0(to: eventHandler)
    return await _commonEntryPoint(passing: args, eventHandler: eventHandler)
  }
}
#endif

/// The entry point to the testing library used by Swift Package Manager.
///
/// - Parameters:
///   - args: A previously-parsed command-line arguments structure to interpret.
///     If `nil`, a new instance is created from the command-line arguments to
///     the current process.
///
/// - Returns: The result of invoking the testing library. The type of this
///   value is subject to change.
///
/// This function examines the command-line arguments represented by `args` and
/// then invokes available tests in the current process.
///
/// - Warning: This function is used by Swift Package Manager. Do not call it
///   directly.
@_disfavoredOverload public func __swiftPMEntryPoint(passing args: __CommandLineArguments_v0? = nil) async -> CInt {
  await _commonEntryPoint(passing: args, eventHandler: nil)
}

/// The entry point to the testing library used by Swift Package Manager.
///
/// - Parameters:
///   - args: A previously-parsed command-line arguments structure to interpret.
///     If `nil`, a new instance is created from the command-line arguments to
///     the current process.
///
/// This function examines the command-line arguments to the current process
/// and then invokes available tests in the current process. When the tests
/// complete, the process is terminated. If tests were successful, an exit code
/// of `EXIT_SUCCESS` is used; otherwise, a (possibly platform-specific) value
/// such as `EXIT_FAILURE` is used instead.
///
/// - Warning: This function is used by Swift Package Manager. Do not call it
///   directly.
public func __swiftPMEntryPoint(passing args: __CommandLineArguments_v0? = nil) async -> Never {
  let exitCode: CInt = await __swiftPMEntryPoint(passing: args)
  exit(exitCode)
}

/// The common implementation of the entry point functions in this file.
///
/// - Parameters:
///   - args: A previously-parsed command-line arguments structure to interpret.
///     If `nil`, a new instance is created from the command-line arguments to
///     the current process.
///   - eventHandler: An event handler
private func _commonEntryPoint(passing args: __CommandLineArguments_v0?, eventHandler: Event.Handler?) async -> CInt {
  let exitCode = Locked(rawValue: EXIT_SUCCESS)

  do {
    let args = try args ?? parseCommandLineArguments(from: CommandLine.arguments())
    if args.listTests {
      for testID in await listTestsForSwiftPM(Test.all) {
#if SWT_TARGET_OS_APPLE && !SWT_NO_FILE_IO
        try? FileHandle.stdout.write("\(testID)\n")
#else
        print(testID)
#endif
      }
    } else {
      var configuration = try configurationForSwiftPMEntryPoint(from: args)
      configuration.eventHandler = { [oldEventHandler = configuration.eventHandler] event, context in
        if case let .issueRecorded(issue) = event.kind, !issue.isKnown {
          exitCode.withLock { exitCode in
            exitCode = EXIT_FAILURE
          }
        }
        oldEventHandler(event, context)
      }
      if let eventHandler {
        configuration.eventHandler = { [oldEventHandler = configuration.eventHandler] event, context in
          eventHandler(event, context)
          oldEventHandler(event, context)
        }
      }

      var options = Event.ConsoleOutputRecorder.Options()
#if !SWT_NO_FILE_IO
      options = .for(.stderr)
#endif
      options.isVerbose = args.verbose

#if !SWT_NO_EXIT_TESTS
      if let exitTest = ExitTest.findInEnvironmentForSwiftPM() {
        await exitTest()
      }
#endif

      await runTests(options: options, configuration: configuration)
    }
  } catch {
#if !SWT_NO_FILE_IO
    try? FileHandle.stderr.write(String(describing: error))
#endif

    exitCode.withLock { exitCode in
      exitCode = EXIT_FAILURE
    }
  }

  return exitCode.rawValue
}

// MARK: - Listing tests

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
  let initialGroups = Dictionary(
    grouping: tests.lazy.map(\.id),
    by: \.nameComponents
  ).values.lazy
    .map { ($0, isAmbiguous: $0.count > 1) }

  // This operation is split to improve type-checking performance.
  return initialGroups.flatMap { testIDs, isAmbiguous in
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

// MARK: - Command-line arguments and configuration

/// A type describing the command-line arguments passed by Swift Package Manager
/// to the testing library's entry point.
///
/// - Warning: This type's definition and JSON-encoded form have not been
///   finalized yet.
///
/// - Warning: This type is used by Swift Package Manager. Do not use it
///   directly.
public struct __CommandLineArguments_v0: Sendable {
  public init() {}

  /// The value of the `--list-tests` argument.
  public var listTests = false

  /// The value of the `--parallel` or `--no-parallel` argument.
  public var parallel = true

  /// The value of the `--verbose` argument.
  public var verbose = false

  /// The value of the `--xunit-output` argument.
  public var xunitOutput: String?

  /// The value of the `--experimental-event-stream-output` argument.
  public var experimentalEventStreamOutput: String?

  /// The value(s) of the `--filter` argument.
  public var filter: [String]?

  /// The value(s) of the `--skip` argument.
  public var skip: [String]?

  /// The value of the `--repetitions` argument.
  public var repetitions: Int?

  /// The value of the `--repeat-until` argument.
  public var repeatUntil: String?
}

extension __CommandLineArguments_v0: Codable {}

/// Initialize this instance given a sequence of command-line arguments passed
/// from Swift Package Manager.
///
/// - Parameters:
///   - args: The command-line arguments to interpret.
///
/// This function generally assumes that Swift Package Manager has already
/// validated the passed arguments.
func parseCommandLineArguments(from args: [String]) throws -> __CommandLineArguments_v0 {
  var result = __CommandLineArguments_v0()

  // Do not consider the executable path AKA argv[0].
  let args = args.dropFirst()

  if args.contains("--list-tests") {
    result.listTests = true
    return result // do not bother parsing the other arguments
  }

  // Parallelization (on by default)
  if args.contains("--no-parallel") {
    result.parallel = false
  }

  if args.contains("--verbose") {
    result.verbose = true
  }

#if !SWT_NO_FILE_IO
  // XML output
  if let xunitOutputIndex = args.firstIndex(of: "--xunit-output"), xunitOutputIndex < args.endIndex {
    result.xunitOutput = args[args.index(after: xunitOutputIndex)]
  }

#if canImport(Foundation)
  // Event stream output (experimental)
  if let eventOutputIndex = args.firstIndex(of: "--experimental-event-stream-output"), eventOutputIndex < args.endIndex {
    result.experimentalEventStreamOutput = args[args.index(after: eventOutputIndex)]
  }
#endif
#endif

  // Filtering
  func filterValues(forArgumentsWithLabel label: String) -> [String] {
    args.indices.lazy
      .filter { args[$0] == label && $0 < args.endIndex }
      .map { args[args.index(after: $0)] }
  }
  result.filter = filterValues(forArgumentsWithLabel: "--filter")
  result.skip = filterValues(forArgumentsWithLabel: "--skip")

  // Set up the iteration policy for the test run.
  if let repetitionsIndex = args.firstIndex(of: "--repetitions"), repetitionsIndex < args.endIndex {
    result.repetitions = Int(args[args.index(after: repetitionsIndex)])
  }
  if let repeatUntilIndex = args.firstIndex(of: "--repeat-until"), repeatUntilIndex < args.endIndex {
    result.repeatUntil = args[args.index(after: repeatUntilIndex)]
  }

  return result
}

/// Get an instance of ``Configuration`` given a sequence of command-line
/// arguments passed from Swift Package Manager.
///
/// - Parameters:
///   - args: A previously-parsed command-line arguments structure to interpret.
///
/// - Returns: An instance of ``Configuration``. Note that the caller is
///   responsible for setting this instance's ``Configuration/eventHandler``
///   property.
///
/// - Throws: If an argument is invalid, such as a malformed regular expression.
@_spi(ForToolsIntegrationOnly)
public func configurationForSwiftPMEntryPoint(from args: __CommandLineArguments_v0) throws -> Configuration {
  var configuration = Configuration()

  // Parallelization (on by default)
  configuration.isParallelizationEnabled = args.parallel

#if !SWT_NO_FILE_IO
  // XML output
  if let xunitOutputPath = args.xunitOutput {
    // Open the XML file for writing.
    let file = try FileHandle(forWritingAtPath: xunitOutputPath)

    // Set up the XML recorder.
    let xmlRecorder = Event.JUnitXMLRecorder { string in
      try? file.write(string)
    }

    let oldEventHandler = configuration.eventHandler
    configuration.eventHandler = { event, context in
      _ = xmlRecorder.record(event, in: context)
      oldEventHandler(event, context)
    }
  }

#if canImport(Foundation)
  // Event stream output (experimental)
  if let eventStreamOutputPath = args.experimentalEventStreamOutput {
    let eventHandler = try _eventHandlerForStreamingEvents_v0(toFileAtPath: eventStreamOutputPath)
    let oldEventHandler = configuration.eventHandler
    configuration.eventHandler = { event, context in
      eventHandler(event, context)
      oldEventHandler(event, context)
    }
  }
#endif
#endif

  // Filtering
  var filters = [Configuration.TestFilter]()
  func testFilter(forRegularExpressions regexes: [String]?, label: String, membership: Configuration.TestFilter.Membership) throws -> Configuration.TestFilter {
    guard let regexes else {
      return .unfiltered
    }

    guard #available(_regexAPI, *) else {
      throw _EntryPointError.featureUnavailable("The `\(label)' option is not supported on this OS version.")
    }
    return try regexes.lazy
      .map { try Regex($0) }
      .map { Configuration.TestFilter(membership: membership, matching: $0) }
      .reduce(into: .unfiltered) { $0.combine(with: $1, using: .or) }
  }
  filters.append(try testFilter(forRegularExpressions: args.filter, label: "--filter", membership: .including))
  filters.append(try testFilter(forRegularExpressions: args.skip, label: "--skip", membership: .excluding))

  configuration.testFilter = filters.reduce(.unfiltered) { $0.combining(with: $1) }

  // Set up the iteration policy for the test run.
  var repetitionPolicy: Configuration.RepetitionPolicy = .once
  var hadExplicitRepetitionCount = false
  if let repetitionCount = args.repetitions, repetitionCount > 0 {
    repetitionPolicy.maximumIterationCount = repetitionCount
    hadExplicitRepetitionCount = true
  }
  if let repeatUntil = args.repeatUntil {
    switch repeatUntil.lowercased() {
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

#if !SWT_NO_EXIT_TESTS
  // Enable exit test handling via __swiftPMEntryPoint().
  configuration.exitTestHandler = ExitTest.handlerForSwiftPM()
#endif

  return configuration
}

// MARK: -

/// The common implementation of ``swiftPMEntryPoint()`` and
/// ``XCTestScaffold/runAllTests(hostedBy:_:)``.
///
/// - Parameters:
///   - options: Options to pass when configuring the console output recorder.
///   - configuration: The configuration to use for running.
func runTests(options: Event.ConsoleOutputRecorder.Options, configuration: Configuration) async {
  var configuration = configuration
  let eventRecorder = Event.ConsoleOutputRecorder(options: options) { string in
#if !SWT_NO_FILE_IO
    try? FileHandle.stderr.write(string)
#endif
  }

  let oldEventHandler = configuration.eventHandler
  configuration.eventHandler = { event, context in
    eventRecorder.record(event, in: context)
    oldEventHandler(event, context)
  }

  let runner = await Runner(configuration: configuration)
  await runner.run()
}

// MARK: - Experimental event streaming

#if canImport(Foundation) && (!SWT_NO_FILE_IO || !SWT_NO_ABI_ENTRY_POINT)
/// A type containing an event snapshot and snapshots of the contents of an
/// event context suitable for streaming over JSON.
///
/// This function is not part of the public interface of the testing library.
/// External adopters are not necessarily written in Swift and are expected to
/// decode the JSON produced for this type in implementation-specific ways.
struct EventAndContextSnapshot {
  /// A snapshot of the event.
  var event: Event.Snapshot

  /// A snapshot of the event context.
  var eventContext: Event.Context.Snapshot
}

extension EventAndContextSnapshot: Codable {}

#if !SWT_NO_FILE_IO
/// Create an event handler that streams events to the file at a given path.
///
/// - Parameters:
///   - path: The path to which events should be streamed. This file will be
///     opened for writing.
///
/// - Throws: Any error that occurs opening `path`. Once `path` is opened,
///   errors that may occur writing to it are handled by the resulting event
///   handler.
///
/// - Returns: An event handler.
///
/// The resulting event handler outputs data in the [JSON Lines](https://jsonlines.org)
/// text format. For each event handled by the resulting event handler, a JSON
/// object representing it and its associated context is created and is written
/// to `path`, followed by a single line feed (`"\n"`) character. These JSON
/// objects are guaranteed not to contain any ASCII newline characters (`"\r"`
/// or `"\n"`) themselves.
///
/// The file at `path` can be a regular file, however to allow for streaming a
/// named pipe is recommended. `mkfifo()` can be used on Darwin and Linux to
/// create a named pipe; `CreateNamedPipeA()` can be used on Windows.
///
/// The file at `path` is closed when this process terminates or the
/// corresponding call to ``Runner/run()`` returns, whichever occurs first.
private func _eventHandlerForStreamingEvents_v0(toFileAtPath path: String) throws -> Event.Handler {
  // Open the event stream file for writing.
  let file = try FileHandle(forWritingAtPath: path)

  return _eventHandlerForStreamingEvents_v0 { eventAndContextJSON in
    func isASCIINewline(_ byte: UInt8) -> Bool {
      byte == 10 || byte == 13
    }

#if DEBUG
    // We don't actually expect the JSON encoder to produce output containing
    // newline characters, so in debug builds we'll log a diagnostic message.
    if eventAndContextJSON.contains(where: isASCIINewline) {
      let message = Event.ConsoleOutputRecorder.warning(
        "JSON encoder produced one or more newline characters while encoding an event snapshot. Please file a bug report at https://github.com/apple/swift-testing/issues/new",
        options: .for(.stderr)
      )
#if SWT_TARGET_OS_APPLE
      try? FileHandle.stderr.write(message)
#else
      print(message)
#endif
    }
#endif

    // Remove newline characters to conform to JSON lines specification.
    var eventAndContextJSON = Array(eventAndContextJSON)
    eventAndContextJSON.removeAll(where: isASCIINewline)

    try? file.withLock {
      try eventAndContextJSON.withUnsafeBytes { eventAndContextJSON in
        try file.write(eventAndContextJSON)
      }
      try file.write("\n")
    }
  }
}
#endif

/// Create an event handler that encodes events as JSON and forwards them to an
/// ABI-friendly event handler.
///
/// - Parameters:
///   - eventHandler: The event handler to forward events to. See
///     ``ABIEntryPoint_v0`` for more information.
///
/// - Returns: An event handler.
///
/// The resulting event handler outputs data as JSON. For each event handled by
/// the resulting event handler, a JSON object representing it and its
/// associated context is created and is passed to `eventHandler`. These JSON
/// objects are guaranteed not to contain any ASCII newline characters (`"\r"`
/// or `"\n"`).
///
/// Note that `_eventHandlerForStreamingEvents_v0(toFileAtPath:)` calls this
/// function and performs additional postprocessing before writing JSON data.
private func _eventHandlerForStreamingEvents_v0(
  to eventHandler: @escaping @Sendable (_ eventAndContextJSON: UnsafeRawBufferPointer) -> Void
) -> Event.Handler {
  return { event, context in
    let snapshot = EventAndContextSnapshot(
      event: Event.Snapshot(snapshotting: event),
      eventContext: Event.Context.Snapshot(snapshotting: context)
    )
    try? JSON.withEncoding(of: snapshot) { eventAndContextJSON in
      eventAndContextJSON.withUnsafeBytes { eventAndContextJSON in
        eventHandler(eventAndContextJSON)
      }
    }
  }
}
#endif

// MARK: - Command-line interface options

extension Event.ConsoleOutputRecorder.Options {
#if !SWT_NO_FILE_IO
  /// The set of options to use when writing to the standard error stream.
  static func `for`(_ fileHandle: borrowing FileHandle) -> Self {
    var result = Self()

    result.useANSIEscapeCodes = _fileHandleSupportsANSIEscapeCodes(fileHandle)
    if result.useANSIEscapeCodes {
      if let noColor = Environment.variable(named: "NO_COLOR"), !noColor.isEmpty {
        // Respect the NO_COLOR environment variable. SEE: https://www.no-color.org
        result.ansiColorBitDepth = 1
      } else if _terminalSupportsTrueColorANSIEscapeCodes {
        result.ansiColorBitDepth = 24
      } else if _terminalSupports256ColorANSIEscapeCodes {
        result.ansiColorBitDepth = 8
      }
    }

#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
    // On macOS, if we are writing to a TTY (i.e. Terminal.app) and the SF Pro
    // font is installed, we can use SF Symbols characters in place of Unicode
    // pictographs. Other platforms do not generally have this font installed.
    // In case rendering with SF Symbols is causing problems (e.g. a third-party
    // terminal app is being used that doesn't support them), allow explicitly
    // toggling them with an environment variable.
    if let environmentVariable = Environment.flag(named: "SWT_SF_SYMBOLS_ENABLED") {
      result.useSFSymbols = environmentVariable
    } else {
      var statStruct = stat()
      result.useSFSymbols = (0 == stat("/Library/Fonts/SF-Pro.ttf", &statStruct))
    }
#endif

    // If color output is enabled, load tag colors from user/package preferences
    // on disk.
    if result.useANSIEscapeCodes && result.ansiColorBitDepth > 1 {
      if let tagColors = try? loadTagColors() {
        result.tagColors = tagColors
      }
    }

    return result
  }

  /// Whether or not the current process's standard error stream is capable of
  /// accepting and rendering ANSI escape codes.
  private static func _fileHandleSupportsANSIEscapeCodes(_ fileHandle: borrowing FileHandle) -> Bool {
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
#else
#warning("Platform-specific implementation missing: terminal colors unavailable")
    return false
#endif
  }

  /// Whether or not the system terminal claims to support true-color ANSI
  /// escape codes.
  private static var _terminalSupportsTrueColorANSIEscapeCodes: Bool {
#if SWT_TARGET_OS_APPLE || os(Linux)
    if let colortermVariable = Environment.variable(named: "COLORTERM") {
      return strstr(colortermVariable, "truecolor") != nil
    }
    return false
#elseif os(Windows)
    // Windows does not set the "COLORTERM" variable, so assume it supports
    // true-color ANSI escape codes. SEE: https://github.com/microsoft/terminal/issues/11057
    true
#else
#warning("Platform-specific implementation missing: terminal colors unavailable")
    return false
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
