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
    var context = ABI.Context()

    var terminator: UInt8?
    repeat {
      let recordJSON: [UInt8]
      (recordJSON, terminator) = try _file.read(until: \.isASCIINewline)

      // Allow other tasks to run after we may have blocked for some time on
      // I/O with the child process.
      await Task.yield()

      if recordJSON.isEmpty {
        continue
      }
      try recordJSON.withUnsafeBytes { recordJSON in
        let versionNumber = try ABI.VersionNumber(fromRecordJSON: recordJSON)
        guard let abi = ABI._version(forVersionNumber: versionNumber) else {
          try? FileHandle.stderr.write("Failed to determine ABI version for JSON record with version number '\(versionNumber)'")
          return
        }
        try _processRecord(
          recordJSON,
          withABIVersion: abi,
          in: &context,
          eventHandler: eventHandler
        )
      }
    } while terminator != nil
  }

  private func _processRecord<V>(
    _ recordJSON: UnsafeRawBufferPointer,
    withABIVersion: V.Type,
    in context: inout ABI.Context,
    eventHandler: @Sendable (borrowing Event, borrowing Event.Context) -> Void
  ) throws where V: ABI._Version {
    let record = try JSON.decode(ABI.Record<ABI.HarnessVersion>.self, from: recordJSON)
    switch record.kind {
    case let .test(encodedTest):
      _ = Test(decoding: encodedTest, in: &context)
    case let .event(encodedEvent):
      guard let event = Event(decoding: encodedEvent, in: &context) else {
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
  }
}
#endif
