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

extension Harness {
  /// Context for the harness' entry point.
  fileprivate struct Context: Sendable {
    /// The first run-started event recorded.
    var runStartedEvent: (Event, Event.Context)?

    /// The last run-ended event recorded.
    var runEndedEvent: (Event, Event.Context)?

    /// All recorded events associated with issues.
    var issueEvents = [(Event, Event.Context)]()
  }

  /// The entry point function used by the harness.
  ///
  /// - Parameters:
  ///   - generators: The event generators to run.
  ///   - arguments: Arguments passed to the harness.
  ///
  /// - Returns: The exit code that the harness should exit with.
  ///
  /// The harness target is responsible for creating `generators`; this function
  /// then handles the remainder of the harness' work.
  package static func entryPoint(
    generatingEventsWith generators: [any Harness.EventGenerator],
    arguments: CommandLineArgumentList
  ) async throws -> CInt {

    let args = try parseCommandLineArguments(from: arguments)
    var configuration = try configurationForEntryPoint(from: args)

    let consoleOutputEnabled = Allocated(Atomic(true))
    configuration.enableConsoleOutput(to: .stderr, togglingWith: consoleOutputEnabled)

    // Track the overall exit code for the run.
    let exitCode = Allocated(Atomic(EXIT_SUCCESS))
    configuration.eventHandler = { [oldEventHandler = configuration.eventHandler] event, eventContext in
      switch event.kind {
      case .testDiscovered:
        _ = exitCode.value.compareExchange(expected: EXIT_SUCCESS, desired: EXIT_NO_TESTS_FOUND, ordering: .sequentiallyConsistent)
      case let .issueRecorded(issue) where issue.isFailure:
        exitCode.value.store(EXIT_FAILURE, ordering: .sequentiallyConsistent)
      default:
        break
      }
      oldEventHandler(event, eventContext)
    }

    // Collate multiple runs into a single virtual run.
    let context = Mutex(Context())

    let generatorCount = generators.count
    for generator in generators {
      do {
        try await _runGenerator(generator, in: context, configuration: configuration, generatorCount: generatorCount)
      } catch {
        // TODO: handle errors at this layer in an interesting way
        exitCode.value.store(EXIT_FAILURE, ordering: .sequentiallyConsistent)
      }
    }

#if !SWT_NO_FILE_IO
    if let runEndedEvent = context.rawValue.runEndedEvent {
      let (event, eventContext) = runEndedEvent
      configuration.eventHandler(event, eventContext)
    }

    if args.verbosity > .min {
      _summarize(context.rawValue.issueEvents, withVerbosity: args.verbosity)
    }
#endif

    return exitCode.value.load(ordering: .sequentiallyConsistent)
  }

  /// The entry point function used by the harness.
  ///
  /// - Parameters:
  ///   - generators: The generators to run.
  ///   - verbosity: The verbosity to run at.
  ///   - xmlOutputPath: The path at which to write JUnit XML output, if any.
  ///
  /// The harness target is responsible for creating `generators`; this function
  /// then handles the remainder of the harness' work.
  ///
  /// This function terminates the current process. It does not return to its
  /// caller.
  package static func entryPoint(
    generatingEventsWith generators: [any Harness.EventGenerator],
    arguments: CommandLineArgumentList
  ) async throws -> Never {
    let exitCode: CInt = try await entryPoint(generatingEventsWith: generators, arguments: arguments)
    exit(exitCode)
  }

  // MARK: -

  private static func _runGenerator(_ generator: some Harness.EventGenerator, in context: borrowing Mutex<Context>, configuration: Configuration, generatorCount: Int) async throws {
    try await generator.run { event, eventContext in
      var recordEvent = true

      switch event.kind {
      case .runStarted:
        // Keep the first run-started event, and discard any subsequent
        // run-started events as redundant.
        context.withLock { context in
          if context.runStartedEvent == nil {
            context.runStartedEvent = (event, eventContext)
          } else {
            recordEvent = false
          }
        }
      case .runEnded:
        // Keep the last run-ended event, and suppress recording any run-ended
        // events until the generator loop is complete.
        context.withLock { context in
          context.runEndedEvent = (event, eventContext)
        }
        recordEvent = false
      case .issueRecorded:
        context.withLock { context in
          context.issueEvents.append((event, eventContext))
        }
      default:
        break
      }

#if !SWT_NO_FILE_IO
      if recordEvent {
        configuration.eventHandler(event, eventContext)
      }
#endif

      if case .runStarted = event.kind, generatorCount > 1 {
        try? FileHandle.stderr.write("Running '\(generator.humanReadableName)'...\n")
      }
    }
  }

#if !SWT_NO_FILE_IO
  private static func _summarize(_ events: [(Event, Event.Context)], withVerbosity verbosity: Int) {
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

    let lines = Event.ConsoleOutputRecorder.lines(for: summaryMessages, options: .for(.stderr))
    try? FileHandle.stderr.withLock {
      for line in lines {
        try FileHandle.stderr.write(line)
      }
    }
  }
#endif
}
