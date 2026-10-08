//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_ABI_JSON_SCHEMA
private import _TestingInternals

extension JSON {
  /// A type that manages writing JSON to some destination (typically a file).
  ///
  /// In non-Embedded Swift, this type trivially forwards output to an instance
  /// of ``FileHandle``. In Embedded Swift, the Platform Abstraction Layer annex
  /// provides functions to initialize a writer, write to it, and deinitialize
  /// it later.
  struct Writer: Sendable, ~Copyable {
#if !hasFeature(Embedded)
    /// The underlying file stream.
    private let _file: FileHandle
#else
    /// The underlying Platform Abstraction Layer annex writer structure.
    private let _writer: swift_testing_json_writer_t
#endif

    /// Construct an instance of this type suitable for writing JSON output to
    /// the specified path.
    ///
    /// - Parameters:
    ///   - path: The path to write to.
    ///
    /// - Throws: If the given path could not be opened for writing or, in
    ///   Embedded Swift, if the platform does not support writing JSON at all.
    init(forWritingAtPath path: String) throws {
#if !hasFeature(Embedded)
      _file = try FileHandle(forWritingAtPath: path)
#else
      _writer = try withUnsafeTemporaryAllocation(of: swift_testing_json_writer_t.self, capacity: 1) { writer in
        guard _swift_testing_beginWritingJSON(path, writer.baseAddress!) else {
          throw SystemError("Could not create a JSON event stream writing to '\(eventStreamOutputPath)'.")
        }
        return writer.baseAddress!.move()
      }
#endif
    }

#if hasFeature(Embedded)
    deinit {
      _swift_testing_deinitJSONWriter(&self)
    }
#endif

    /// Write the given JSON output to this writer's destination, optionally
    /// followed by a terminator character.
    ///
    /// - Parameters:
    ///   - json: A buffer containing JSON output to write.
    ///   - terminator: If not `nil`, a terminator character to write after
    ///     `json`. This byte is not included in `json` to avoid creating
    ///     unnecessary copies of `json` in memory.
    ///
    /// - Throws: Any error that occurs while writing `json` or `terminator`.
    func write(_ json: UnsafeRawBufferPointer, terminatedBy terminator: UInt8?) throws {
#if !hasFeature(Embedded)
      _ = try _file.withLock {
        try _file.write(json)
        if let terminator {
          try _file.write(terminator)
        }
      }
#else
      guard let jsonBaseAddress = json.baseAddress else {
        return
      }
      withUnsafePointer(to: self) { writer in
        var terminator = terminator
        _swift_testing_writeJSON(writer, jsonBaseAddress, json.count, &terminator)
      }
#endif
    }
  }
}
#endif
