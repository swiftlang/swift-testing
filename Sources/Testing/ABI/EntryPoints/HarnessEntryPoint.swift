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
  package typealias HarnessVersion = ExperimentalVersion
}

package func harnessEntryPoint(
  running grommets: [any Grommet]
) async throws -> CInt {
  var exitCodes = [CInt]()

#if !SWT_NO_FILE_IO
  let eventRecorder = Event.ConsoleOutputRecorder(options: .for(.stderr)) { string in
    try? FileHandle.stderr.write(string)
  }
#endif

  let grommetCount = grommets.count
  for (i, grommet) in grommets.enumerated() {
    let exitCode = Atomic<CInt>(EXIT_SUCCESS)

    func open(_ grommet: some Grommet) async throws {
      try await grommet.run { event, eventContext in
        var recordEvent = true

        switch event.kind {
        case .testDiscovered:
          _ = exitCode.compareExchange(expected: EXIT_SUCCESS, desired: EXIT_NO_TESTS_FOUND, ordering: .sequentiallyConsistent)
#if !SWT_NO_FILE_IO
        case .runStarted:
          if i > 0 {
            recordEvent = false
          }
          if grommetCount > 1 {
            try? FileHandle.stderr.write("Running '\(grommet.grommetName)'...\n")
          }
        case .runEnded:
          if i != grommets.count - 1 {
            recordEvent = false
          }
#endif
        case let .issueRecorded(issue):
          if issue.isFailure {
            exitCode.store(EXIT_FAILURE, ordering: .sequentiallyConsistent)
          }
        default:
          break
        }

#if !SWT_NO_FILE_IO
        if recordEvent {
          eventRecorder.record(event, in: eventContext)
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

package func harnessEntryPoint(
  running grommets: [any Grommet]
) async throws -> Never {
  let exitCode: CInt = try await harnessEntryPoint(running: grommets)
  exit(exitCode)
}
