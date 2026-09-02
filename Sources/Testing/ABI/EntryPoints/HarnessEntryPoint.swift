//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

#if canImport(Synchronization)
private import Synchronization
#endif

extension ABI {
  /// The JSON schema version the harness uses by default.
  ///
  /// The harness is able to decode record JSON of any supported schema version,
  /// but uses this version by default.
  package typealias HarnessVersion = ExperimentalVersion
}

/// The entry point function used by the harness.
///
/// - Parameters:
///   - adapters: The adapters to run.
///   - arguments: Arguments passed to the harness.
///
/// - Returns: The exit code that the harness should exit with.
///
/// The harness target is responsible for creating `adapters`; this function
/// then handles the remainder of the harness' work.
package func harnessEntryPoint(
  running adapters: [any Event.Adapter],
  arguments: CommandLineArgumentList
) async throws -> CInt {
  var exitCodes = [CInt]()

  let args = try parseCommandLineArguments(from: arguments.arguments)

#if !SWT_NO_FILE_IO
  let (eventRecorder, configuration) = {
    var eventRecorder: Event.ConsoleOutputRecorder?
    if args.verbosity > .min {
      eventRecorder = .init(options: .for(.stderr)) { string in
        try? FileHandle.stderr.write(string)
      }
    }

    var configuration = Configuration()
    configuration.verbosity = args.verbosity

    return (eventRecorder, configuration)
  }()

  let xmlOutputRecorder: Event.JUnitXMLRecorder? = try {
    guard let xmlOutputPath = args.xunitOutput else {
      return nil
    }
    let file = try FileHandle(forWritingAtPath: xmlOutputPath)
    return Event.JUnitXMLRecorder { string in
      try? file.write(string)
    }
  }()

  let eventHandler: (@Sendable (borrowing Event, borrowing Event.Context) -> Void)? = try {
    guard let eventStreamOutputPath = args.eventStreamOutputPath else {
      return nil
    }
    let file = try FileHandle(forWritingAtPath: eventStreamOutputPath)
    return try eventHandlerForStreamingEvents(withVersionNumber: args.eventStreamVersionNumber, encodeAsJSONLines: true) { json in
      _ = try? file.withLock {
        try file.write(json)
        try file.write("\n")
      }
    }
  }()
#endif

  // Collate multiple runs into a single virtual run.
  let runStartedEvent = Mutex<(Event, Event.Context)?>()
  let runEndedEvent = Mutex<(Event, Event.Context)?>()
  let issueEvents = Mutex<[(Event, Event.Context)]>()

#if !SWT_NO_SIGINFO
  let siginfoHandler = SIGINFOHandler {
    guard let lines = eventRecorder?.summarize() else {
      return
    }
    _ = try? FileHandle.stderr.withLock {
      for line in lines {
        try FileHandle.stderr.write(line)
      }
    }
  }
  defer {
    extendLifetime(siginfoHandler)
  }
#endif

  let adapterCount = adapters.count
  for adapter in adapters {
    let exitCode = Atomic<CInt>(EXIT_SUCCESS)

    func open(_ adapter: some Event.Adapter) async throws {
      try await adapter.run { event, eventContext in
        var recordEvent = true

        switch event.kind {
        case .testDiscovered:
          _ = exitCode.compareExchange(expected: EXIT_SUCCESS, desired: EXIT_NO_TESTS_FOUND, ordering: .sequentiallyConsistent)
        case .runStarted:
          // Keep the first run-started event, and discard any subsequent
          // run-started events as redundant.
          runStartedEvent.withLock { runStartedEvent in
            if runStartedEvent == nil {
              runStartedEvent = (event, eventContext)
            } else {
              recordEvent = false
            }
          }
        case .runEnded:
          // Keep the last run-ended event, and suppress recording any run-ended
          // events until the adapter loop is complete.
          runEndedEvent.withLock { runEndedEvent in
            runEndedEvent = (event, eventContext)
          }
          recordEvent = false
        case let .issueRecorded(issue):
          if issue.isFailure {
            exitCode.store(EXIT_FAILURE, ordering: .sequentiallyConsistent)
          }
          issueEvents.withLock { issueEvents in
            issueEvents.append((event, eventContext))
          }
        default:
          break
        }

#if !SWT_NO_FILE_IO
        if recordEvent, let eventRecorder {
          eventRecorder.record(event, in: eventContext, configuration: configuration)
          xmlOutputRecorder?.record(event, in: eventContext)
          eventHandler?(event, eventContext)
        }
#endif

        if case .runStarted = event.kind, adapterCount > 1 {
          try? FileHandle.stderr.write("Running '\(adapter.adapterName)'...\n")
        }
      }
    }

    do {
      try await open(adapter)
    } catch {
      // TODO: handle errors at this layer in an interesting way
      exitCode.store(EXIT_FAILURE, ordering: .sequentiallyConsistent)
    }

    exitCodes.append(exitCode.load(ordering: .sequentiallyConsistent))
  }

#if !SWT_NO_FILE_IO
  if let runEndedEvent = runEndedEvent.rawValue, let eventRecorder {
    let (event, eventContext) = runEndedEvent
    eventRecorder.record(event, in: eventContext, configuration: configuration)
    xmlOutputRecorder?.record(event, in: eventContext)
    eventHandler?(event, eventContext)
  }

  if args.verbosity > .min, let eventRecorder {
    _summarize(issueEvents.rawValue, using: eventRecorder, withVerbosity: args.verbosity)
  }
#endif

  let noTestsFound = exitCodes.allSatisfy { $0 == EXIT_NO_TESTS_FOUND }
  if noTestsFound {
    return EXIT_NO_TESTS_FOUND
  }
  let succeeded = exitCodes.allSatisfy { $0 == EXIT_SUCCESS }
  if succeeded {
    return EXIT_SUCCESS
  }
  return EXIT_FAILURE
}

/// The entry point function used by the harness.
///
/// - Parameters:
///   - adapters: The adapters to run.
///   - verbosity: The verbosity to run at.
///   - xmlOutputPath: The path at which to write JUnit XML output, if any.
///
/// The harness target is responsible for creating `adapters`; this function
/// then handles the remainder of the harness' work.
///
/// This function terminates the current process. It does not return to its
/// caller.
package func harnessEntryPoint(
  running adapters: [any Event.Adapter],
  arguments: CommandLineArgumentList
) async throws -> Never {
  let exitCode: CInt = try await harnessEntryPoint(running: adapters, arguments: arguments)
  exit(exitCode)
}

// MARK: -

#if !SWT_NO_FILE_IO
private func _summarize(_ events: [(Event, Event.Context)], using eventRecorder: Event.ConsoleOutputRecorder, withVerbosity verbosity: Int) {
  guard verbosity >= 0 else {
    // Don't summarize in quiet mode.
    return
  }

  let issueEvents = events.filter { event, _ in
    if case let .issueRecorded(issue) = event.kind, !issue.isKnown {
      return true
    }
    return false
  }
  if issueEvents.isEmpty {
    return
  }

  var issuesByTest = [Test: [Issue]]()
  for (event, eventContext) in issueEvents {
    guard let test = eventContext.test,
          case let .issueRecorded(issue) = event.kind else {
      continue
    }
    issuesByTest[test, default: []].append(issue)
  }

  let anyFailure: Bool = issuesByTest.values.lazy
    .flatMap(\.self)
    .contains(where: \.isFailure)

  let terminalWidth: Int = {
#if SWT_TARGET_OS_APPLE
    var windowSize = winsize()
    if 0 == swt_ioctl_TIOCGWINSZ(STDERR_FILENO, &windowSize) {
      return Int(clamping: windowSize.ws_col)
    }
#endif
    return 40
  }()

  var summaryMessages = [Event.HumanReadableOutputRecorder.Message]()
  summaryMessages += [
    .init(stringValue: String(repeating: "=", count: min(40, terminalWidth / 2))),
    .init(
      symbol: anyFailure ? .fail : .pass(knownIssueCount: 1),
      stringValue: "The following \(issuesByTest.keys.count.counting("test")) recorded \(issueEvents.count.counting("issue")):"
    ),
  ]
  let sortedIssuesByTest: [(key: Test, value: [Issue])] = issuesByTest.sorted { lhs, rhs in
    lhs.key.sourceLocation < rhs.key.sourceLocation
  }
  for (test, issues) in sortedIssuesByTest {
    summaryMessages += [
      {
        let sourceLocation = test.sourceLocation
        let stringValue = if sourceLocation != .unknown {
          "\(sourceLocation) - \(test.humanReadableName(withVerbosity: verbosity)):"
        } else {
          "\(test.humanReadableName(withVerbosity: verbosity)):"
        }
        return .init(
          symbol: .default,
          stringValue: stringValue
        )
      }(),
    ]
    summaryMessages += issues.map { issue in
      let stringValue = if let sourceLocation = issue.sourceLocation, sourceLocation != .unknown {
        "\(sourceLocation) - \(issue)"
      } else {
        "\(issue)"
      }
      return .init(
        symbol: issue.isFailure ? .fail : .pass(knownIssueCount: 1),
        indentation: 1,
        stringValue: stringValue
      )
    }
  }

  let orphanedIssues: [Issue] = issueEvents.compactMap { event, eventContext in
    if eventContext.test != nil {
      return nil
    }
    guard case let .issueRecorded(issue) = event.kind else {
      return nil
    }
    return issue
  }
  if !orphanedIssues.isEmpty {
    let anyFailure = orphanedIssues.contains(where: \.isFailure)
    summaryMessages += [
      .init(
        symbol: anyFailure ? .fail : .pass(knownIssueCount: 1),
        stringValue: "As well, the following \(orphanedIssues.count.counting("issue")) \(orphanedIssues.count.counting("was", or: "were")) recorded without an associated test:"
      )
    ]
    summaryMessages += orphanedIssues.map { issue in
      let stringValue = if let sourceLocation = issue.sourceLocation, sourceLocation != .unknown {
        "\(sourceLocation) - \(issue)"
      } else {
        "\(issue)"
      }
      return .init(
        symbol: issue.isFailure ? .fail : .pass(knownIssueCount: 1),
        indentation: 1,
        stringValue: stringValue
      )
    }
  }

  eventRecorder.record(summaryMessages)
}
#endif
