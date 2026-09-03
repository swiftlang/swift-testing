//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_PROCESS_SPAWNING
private import _TestingInternals

#if canImport(Foundation)
private import Foundation
#endif

#if canImport(Synchronization)
private import Synchronization
#endif

extension Harness {
  /// A class whose instances spawn a child process that runs tests, encodes
  /// their events as [JSON Lines](https://jsonlines.org), and passes them back
  /// to this (the parent) process.
  ///
  /// On Apple platforms, instances of this class spawn `swiftpm-testing-helper`
  /// while on other platforms, they spawn the test product directly.
  ///
  /// This class does not support cross-target testing. All tests run on the
  /// current system only.
  package final class LocalProcessEventGenerator: EventGenerator {
    /// The command-line arguments to pass to the child process, not including
    /// those added by this instance.
    private let _commandLineArguments: [String]

#if SWT_TARGET_OS_APPLE
    /// The path to the test product's binary (inside the `.xctest` bundle).
    private let _testProductBinaryPath: String

    /// The path to the `swiftpm-testing-helper` tool.
    private let _swiftPMTestingHelperPath: String

    package init(testProductBinaryPath: String, swiftPMTestingHelperPath: String, commandLineArguments: [String]) {
      _testProductBinaryPath = testProductBinaryPath
      _swiftPMTestingHelperPath = swiftPMTestingHelperPath
      _commandLineArguments = commandLineArguments
    }
#else
    /// The path to the test product.
    private let _testProductPath: String

    package init(testProductPath: String, commandLineArguments: [String]) {
      _testProductPath = testProductPath
      _commandLineArguments = commandLineArguments
    }
#endif

    package var humanReadableName: String {
#if SWT_TARGET_OS_APPLE
      let path = _testProductBinaryPath
#else
      let path = _testProductPath
#endif
#if canImport(Foundation)
      return (path as NSString).lastPathComponent
#else
      return path
#endif
    }

    package func listTests() async throws -> [Test] {
      let result = Mutex<[Test]>()

      try await _run(listOnly: true) { event, eventContext in
        guard case .testDiscovered = event.kind, let test = eventContext.test else {
          return
        }
        result.withLock { result in
          result.append(test)
        }
      }

      return result.rawValue
    }

    package func run(_ eventHandler: @Sendable (borrowing Event, borrowing Event.Context) async throws -> Void) async throws {
      try await withoutActuallyEscaping(eventHandler) { eventHandler in
        try await _run(listOnly: false, eventHandler)
      }
    }

    /// The implementation of ``listTests()`` and ``run(_:)``.
    ///
    /// - Parameters:
    ///   - listOnly: Whether to run the `list` subcommand.
    ///
    /// For more information, see ``Harness/EventGenerator/listTests()`` and
    /// ``Harness/EventGenerator/run(_:)``.
    ///
    /// This function is factored out to allow treating `eventHandler` as an
    /// escaping closure.
    private func _run(listOnly: Bool, _ eventHandler: @escaping @Sendable (borrowing Event, borrowing Event.Context) async throws -> Void) async throws {
      try await withThrowingTaskGroup(of: Void.self) { taskGroup in
        var backChannelReadEnd: FileHandle!
        var backChannelWriteEnd: FileHandle!
        try FileHandle.makePipe(readEnd: &backChannelReadEnd, writeEnd: &backChannelWriteEnd)

        var arguments = [String]()
#if SWT_TARGET_OS_APPLE
        arguments += ["--test-bundle-path", _testProductBinaryPath]
#endif
        arguments += [
          "--testing-library", "swift-testing",
        ]
        arguments += _commandLineArguments
#if os(Windows)
        backChannelWriteEnd.withUnsafeWindowsHANDLE { handle in
          guard let handle else {
            return
          }

          arguments += [
            "--__harness-event-stream-handle", String(describing: UInt(bitPattern: handle)),
          ]
        }
#else
        backChannelWriteEnd.withUnsafePOSIXFileDescriptor { fd in
          guard let fd else {
            return
          }

          arguments += [
            "--__harness-event-stream-file-descriptor", String(describing: fd),
          ]
        }
#endif

        if listOnly {
          arguments.append("list")
        } else {
          arguments.removeAll { $0 == "--list-tests" || $0 == "list" }
        }

#if SWT_TARGET_OS_APPLE
        let executablePath = _swiftPMTestingHelperPath
#else
        let executablePath = _testProductPath
#endif

        let processID = try withUnsafePointer(to: backChannelWriteEnd) { backChannelWriteEnd in
          try spawnExecutable(
            atPath: executablePath,
            arguments: arguments,
            environment: Environment.get(),
            standardOutput: .stdout,
            standardError: .stderr,
            additionalFileHandles: [backChannelWriteEnd]
          )
        }
        backChannelWriteEnd.close()

        // Wait for the child process to terminate.
        taskGroup.addTask(name: decorateTaskName("harness", withAction: "running test process")) {
          let exitStatus = try await wait(for: processID)

          switch exitStatus {
          case .exitCode(EXIT_SUCCESS), .exitCode(EXIT_FAILURE), .exitCode(EXIT_NO_TESTS_FOUND):
            return
          default:
            // Handle abnormal termination.
            var exitCodeDescription = switch exitStatus {
            case let .exitCode(exitCode):
              "exit code \(exitCode)"
            case let .signal(signal):
              "signal \(signal)"
            }
            if let name = exitStatus.name {
              exitCodeDescription += " (\(name))"
            }

            let issue = Issue(
              kind: .unconditional,
              comments: ["The test process exited with \(exitCodeDescription)"],
              sourceContext: SourceContext(backtrace: nil, sourceLocation: nil)
            )
            let event = Event(.issueRecorded(issue), testID: nil, testCaseID: nil)
            let eventContext = Event.Context(test: nil, testCase: nil, iteration: nil, configuration: nil)
            try await eventHandler(event, eventContext)
          }
        }

        // Read events back out from the back channel.
        let fileGenerator = JSONLinesFileEventGenerator(readingFrom: backChannelReadEnd!)
        taskGroup.addTask(name: decorateTaskName("harness", withAction: "reading events from test process")) {
          try await fileGenerator.run(eventHandler)
        }

        try await taskGroup.waitForAll()
      }
    }

  }
}
#endif
