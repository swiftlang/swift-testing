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
      arguments += CommandLine.arguments
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
      let executablePath = _testProductBinaryPath
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

      taskGroup.addTask {
        _ = try await wait(for: processID)
      }
      taskGroup.addTask { [backChannelReadEnd] in
        try await _processRecords(fromBackChannel: backChannelReadEnd!, eventHandler: eventHandler)
      }
      try await taskGroup.waitForAll()
    }

  }

  private func _processRecords(
    fromBackChannel backChannel: borrowing FileHandle,
    eventHandler: @Sendable (borrowing Event, borrowing Event.Context) -> Void
  ) async throws {
    var context = ABI.Context()

    var terminator: UInt8?
    repeat {
      let recordJSON: [UInt8]
      (recordJSON, terminator) = try backChannel.read(until: \.isASCIINewline)

      // Allow other tasks to run after we may have blocked for some time on
      // I/O with the child process.
      await Task.yield()

      if recordJSON.isEmpty {
        continue
      }
      let record = try recordJSON.withUnsafeBufferPointer { recordJSON in
        try JSON.decode(ABI.Record<ABI.HarnessVersion>.self, from: .init(recordJSON))
      }
      switch record.kind {
      case let .test(encodedTest):
        _ = Test(decoding: encodedTest, in: &context)
      case let .event(encodedEvent):
        guard let event = Event(decoding: encodedEvent) else {
          try? FileHandle.stderr.write("Failed to decode \(encodedEvent)")
          return
        }
        let eventContext = Event.Context(
          test: encodedEvent.testID.flatMap(context.test(identifiedBy:)),
          testCase: nil,
          iteration: encodedEvent.iteration,
          configuration: nil
        )
        eventHandler(event, eventContext)
      }
    } while terminator != nil
  }
}
#endif
