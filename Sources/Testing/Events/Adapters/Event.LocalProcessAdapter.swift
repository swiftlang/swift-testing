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

extension Event {
  /// A class whose instances spawn a child process that runs tests, encodes
  /// their events as [JSON Lines](https://jsonlines.org), and passes them back
  /// to this (the parent) process.
  ///
  /// On Apple platforms, instances of this class spawn `swiftpm-testing-helper`
  /// while on other platforms, they spawn the test product directly.
  ///
  /// This class does not support cross-target testing. All tests run on the
  /// current system only.
  package final class LocalProcessAdapter: Adapter {
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

    package var adapterName: String {
#if SWT_TARGET_OS_APPLE
      _testProductBinaryPath
#else
      _testProductPath
#endif
    }

    package func run(_ eventHandler: @escaping @Sendable (borrowing Event, borrowing Event.Context) async throws -> Void) async throws {
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

          if exitStatus == .exitCode(EXIT_SUCCESS) {
            return
          }

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

        // Read events back out from the back channel.
        let fileAdapter = JSONLinesFileAdapter(readingFrom: backChannelReadEnd!)
        taskGroup.addTask(name: decorateTaskName("harness", withAction: "reading events from test process")) {
          try await fileAdapter.run(eventHandler)
        }

        try await taskGroup.waitForAll()
      }

    }
  }
}
#endif
