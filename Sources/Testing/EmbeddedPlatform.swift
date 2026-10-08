//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

/// This file contains abstractions over functionality that, under Embedded
/// Swift, is provided by Swift Testing's Platform Abstraction Layer annex.

// MARK: - Console output

/// Writes a Swift string to the current system's console.
///
/// - Parameters:
///   - string: The string to write.
///   - useStandardOutputIfAvailable: If the platform supports full file I/O
///     then write to `stdout` instead of `stderr`. The default is to write to
///     `stderr`.
///
/// The testing library uses this function to write a _human-readable_
/// transcript of a test run. This function abstracts away the destination of
/// console output which differs between non-Embedded Swift and Embedded Swift
/// builds.
@inline(always) func writeToConsole(_ string: String, useStandardOutputIfAvailable: Bool = false) {
  if string.isEmpty {
    return
  }

#if !hasFeature(Embedded)
#if !SWT_NO_FILE_IO
  let file = useStandardOutputIfAvailable ? FileHandle.stdout : FileHandle.stderr
  try? file.write(string)
#else
  if useStandardOutputIfAvailable {
    print(string, terminator: "")
  } else {
    // TODO: determine whether we can reliably call `print()` here or something else
  }
#endif
#else
  var string = string
  string.withUTF8 { string in
    _swift_testing_writeToConsole(string.baseAddress!, string.count)
  }
#endif
}

// MARK: - JSON output

#if !SWT_NO_ABI_JSON_SCHEMA && (!SWT_NO_FILE_IO || hasFeature(Embedded))
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
    /// The `path` argument to pass to `_swift_testing_writeJSON()`.
    private let _path: String
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
      _path = path
#endif
    }

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
      if let jsonBaseAddress = json.baseAddress {
        _path.withCString { path in
          if var terminator {
            _swift_testing_writeJSON(path, jsonBaseAddress, json.count, &terminator)
          } else {
            _swift_testing_writeJSON(path, jsonBaseAddress, json.count, nil)
          }
        }
      }
#endif
    }
  }
}
#endif

// MARK: -

#if hasFeature(Embedded)
/// Exits the current process as if the C `exit()` function were called.
///
/// This declaration is provided because the function is declared in the core
/// Platform Abstraction Layer header and is used by the testing library below.
@_extern(c) private func _swift_exit(_ exitCode: CInt)
#endif

/// Exits the current process as if the C `exit()` function were called.
///
/// - Parameters:
///   - exitCode: The exit code for the process.
///
/// The testing library uses this function to exit the test process and exit
/// test child processes. This function is a convenience over C's `exit()` and
/// the Platform Abstraction Layer's `_swift_exit()`.
///
/// - Bug: This symbol is declared as a constant closure rather than a function
///   to work around a compiler crash on Android when verifying this function's
///   SIL. ([swift-#92180](https://github.com/swiftlang/swift/issues/92180))
let exit: @Sendable (_ exitCode: CInt) -> Never = { exitCode in
#if !hasFeature(Embedded)
  _TestingInternals.exit(exitCode)
#else
  _swift_exit(exitCode)
  swt_unreachable()
#endif
}
