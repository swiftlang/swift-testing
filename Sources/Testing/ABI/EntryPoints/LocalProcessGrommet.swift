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
package struct LocalProcessGrommet: Grommet {
#if SWT_TARGET_OS_APPLE
  private var _testProductBinaryPath: String
  private var _swiftPMTestingHelperPath: String

  package init(testProductBinaryPath: String, swiftPMTestingHelperPath: String) {
    _testProductBinaryPath = testProductBinaryPath
    _swiftPMTestingHelperPath = swiftPMTestingHelperPath
  }
#else
  private var _testProductPath: String

  package init(testProductPath: String) {
    _testProductPath = testProductPath
  }
#endif

  package var grommetName: String {
#if SWT_TARGET_OS_APPLE
    _testProductBinaryPath
#else
    _testProductPath
#endif
  }

  package func run(_ eventHandler: @escaping @Sendable (borrowing Event, borrowing Event.Context) -> Void) async throws {
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
      arguments += CommandLine.arguments.dropFirst()
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
        _ = try await wait(for: processID)
      }

      // Read events back out from the back channel.
      let fileGrommet = FileGrommet(readingFrom: backChannelReadEnd!)
      taskGroup.addTask(name: decorateTaskName("harness", withAction: "reading events from test process")) {
        try await fileGrommet.run(eventHandler)
      }

      try await taskGroup.waitForAll()
    }

  }
}
#endif
