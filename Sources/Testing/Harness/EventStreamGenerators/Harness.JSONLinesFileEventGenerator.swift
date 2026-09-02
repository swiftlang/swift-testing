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
#if canImport(Foundation)
private import Foundation
#endif

extension Harness {
  /// A class whose instances can read from files containing previously-written
  /// JSON event streams and transform their contents into event streams.
  ///
  /// Instances of this class can read files that contain JSON event streams
  /// encoded as [JSON Lines](https://jsonlines.org).
  package final class JSONLinesFileEventGenerator: EventGenerator {
    /// The file that this generator is reading from.
    private let _file: FileHandle

    /// The path to `_file` that was passed when this instance was created.
    private let _filePath: String

    init(readingFrom file: consuming FileHandle, atPath filePath: String? = nil) {
      _file = file
      _filePath = filePath ?? ""
    }

    package convenience init(readingFromFileAtPath filePath: String) throws {
      let file = try FileHandle(forReadingAtPath: filePath)
      self.init(readingFrom: file, atPath: filePath)
    }

    package var humanReadableName: String {
#if canImport(Foundation)
      (_filePath as NSString).lastPathComponent
#else
      _filePath
#endif
    }

    package func run(_ eventHandler: @Sendable (borrowing Event, borrowing Event.Context) async throws -> Void) async throws {
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

        // FIXME: need async withUnsafeBytes() in the stdlib
        let recordJSONCopy = UnsafeMutableRawBufferPointer.allocate(byteCount: recordJSON.count, alignment: 1)
        _ = recordJSONCopy.initializeMemory(as: UInt8.self, fromContentsOf: recordJSON)
        defer {
          recordJSONCopy.deallocate()
        }
        
        if let eventAndContext = ABI.decodeEvent(fromRecordJSON: .init(recordJSONCopy), in: &context) {
          try await eventHandler(eventAndContext.event, eventAndContext.context)
        }
      } while terminator != nil
    }
  }
}
#endif
