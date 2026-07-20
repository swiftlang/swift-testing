//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_FILE_IO
package final class FileGrommet: Grommet {
  private let _file: FileHandle

  init(readingFrom file: consuming FileHandle) {
    _file = file
  }

  package convenience init(readingFromFileAtPath filePath: String) throws {
    let file = try FileHandle(forReadingAtPath: filePath)
    self.init(readingFrom: file)
  }

  package func run(_ eventHandler: @escaping @Sendable (borrowing Event, borrowing Event.Context) -> Void) async throws {
    try await _processRecords(fromBackChannel: _file, eventHandler: eventHandler)
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
