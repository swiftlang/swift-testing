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

#if !SWT_NO_SIGINFO && !SWT_TARGET_OS_APPLE
private import Dispatch
#endif

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
///   - grommets: The grommets to run.
///   - verbosity: The verbosity to run at.
///
/// - Returns: The exit code that the harness should exit with.
///
/// The harness target is responsible for creating `grommets`; this function
/// then handles the remainder of the harness' work.
package func harnessEntryPoint(
  running grommets: [any Grommet],
  verbosity: Int
) async throws -> CInt {
  var exitCodes = [CInt]()

#if !SWT_NO_FILE_IO
  let (eventRecorder, configuration) = {
    var eventRecorder: Event.ConsoleOutputRecorder?
    if verbosity > .min {
      eventRecorder = .init(options: .for(.stderr)) { string in
        try? FileHandle.stderr.write(string)
      }
    }

    var configuration = Configuration()
    configuration.verbosity = verbosity

    return (eventRecorder, configuration)
  }()
#endif

  // Collate multiple runs into a single virtual run.
  let runStartedEvent = Mutex<(Event, Event.Context)?>()
  let runEndedEvent = Mutex<(Event, Event.Context)?>()

#if !SWT_NO_SIGINFO
  let siginfoSource = DispatchSource.makeSignalSource(signal: SIGINFO, queue: .main)
  siginfoSource.setEventHandler {
    // TODO: SIGINFO handling
  }
  siginfoSource.resume()
  defer {
    extendLifetime(siginfoSource)
  }
#endif

  let grommetCount = grommets.count
  for grommet in grommets {
    let exitCode = Atomic<CInt>(EXIT_SUCCESS)

    func open(_ grommet: some Grommet) async throws {
      try await grommet.run { event, eventContext in
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
          if grommetCount > 1 {
            try? FileHandle.stderr.write("Running '\(grommet.grommetName)'...\n")
          }
        case .runEnded:
          // Keep the last run-ended event, and suppress recording any run-ended
          // events until the grommet loop is complete.
          runEndedEvent.withLock { runEndedEvent in
            runEndedEvent = (event, eventContext)
          }
          recordEvent = false
        case let .issueRecorded(issue):
          if issue.isFailure {
            exitCode.store(EXIT_FAILURE, ordering: .sequentiallyConsistent)
          }
        default:
          break
        }

#if !SWT_NO_FILE_IO
        if recordEvent, let eventRecorder {
          eventRecorder.record(event, in: eventContext, configuration: configuration)
        }
#endif
      }
    }

    do {
      try await open(grommet)
    } catch {
      // TODO: handle errors at this layer in an interesting way
      exitCode.store(EXIT_FAILURE, ordering: .sequentiallyConsistent)
    }

    exitCodes.append(exitCode.load(ordering: .sequentiallyConsistent))
  }

#if !SWT_NO_FILE_IO
  if let runEndedEvent = runEndedEvent.rawValue, let eventRecorder {
    eventRecorder.record(runEndedEvent.0, in: runEndedEvent.1, configuration: configuration)
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
///   - grommets: The grommets to run.
///   - verbosity: The verbosity to run at.
///
/// The harness target is responsible for creating `grommets`; this function
/// then handles the remainder of the harness' work.
///
/// This function terminates the current process. It does not return to its
/// caller.
package func harnessEntryPoint(
  running grommets: [any Grommet],
  verbosity: Int
) async throws -> Never {
  let exitCode: CInt = try await harnessEntryPoint(running: grommets, verbosity: verbosity)
  exit(exitCode)
}
