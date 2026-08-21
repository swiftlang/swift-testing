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
  private let _filePath: String

  init(readingFrom file: consuming FileHandle, atPath filePath: String? = nil) {
    _file = file
    _filePath = filePath ?? ""
  }

  package convenience init(readingFromFileAtPath filePath: String) throws {
    let file = try FileHandle(forReadingAtPath: filePath)
    self.init(readingFrom: file, atPath: filePath)
  }

  package var grommetName: String {
    _filePath
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
      recordJSON.withUnsafeBytes { recordJSON in
        if let eventAndContext = ABI.decodeEvent(fromRecordJSON: recordJSON, in: &context) {
          eventHandler(eventAndContext.event, eventAndContext.context)
        }
      }
    } while terminator != nil
  }
}
#endif
