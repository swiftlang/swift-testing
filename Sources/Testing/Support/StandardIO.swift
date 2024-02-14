//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import TestingInternals

#if !SWT_NO_FILE_IO
/// An enumeration describing the C standard I/O streams that the testing
/// library monitors.
@_spi(ExperimentalEventHandling)
public enum StandardIOStream: Sendable, Codable {
  /// The standard output stream, i.e. `stdout`.
  case standardOutput

  /// The standard error stream, i.e. `stderr`.
  case standardError
}

#if SWT_TARGET_OS_APPLE || os(Linux)
/// A type representing a listener stream that replaces `stdout` or `stderr`.
private struct _ListenerStream {
  /// Which stream this instance represents.
  var stream: StandardIOStream

  /// Any output that has accumulated via calls to ``append(_:count:)``.
  private var _buffer = [CChar]()

  /// Create a new C file handle backed by an instance of this type.
  ///
  /// - Parameters:
  ///   - stream: Which stream the new instance will represent.
  ///
  /// - Returns: A new C file handle that handles output for `stream` and
  ///   posts events when output is recorded. The resulting C file handle is not
  ///   yet assigned to `stdout` or `stderr`.
  static func funopen(as stream: StandardIOStream) -> SWT_FILEHandle {
    let buffer = UnsafeMutablePointer<Self>.allocate(capacity: 1)
    buffer.initialize(to: Self(stream: stream))

    func writefn(_ cookie: UnsafeMutableRawPointer?, _ bytes: UnsafePointer<CChar>?, _ count: Int) -> Int {
      if let bytes, count > 0 {
        cookie!.withMemoryRebound(to: Self.self, capacity: 1) { buffer in
          buffer.pointee.append(bytes, count: Int(count))
        }
      }
      return count
    }

    func closefn(_ cookie: UnsafeMutableRawPointer?) -> Int {
      cookie!.withMemoryRebound(to: Self.self, capacity: 1) { buffer in
        buffer.deinitialize(count: 1)
        buffer.deallocate()
        return 0
      }
    }
#if SWT_TARGET_OS_APPLE
    let result = TestingInternals.funopen(
      buffer,
      nil, // readfn
      { Int32(writefn($0, $1, Int($2))) }, // writefn
      nil, // seekfn
      { Int32(closefn($0)) } // closefn
    )!
#elseif os(Linux)
    var funcs = cookie_io_functions_t()
    funcs.write = { writefn($0, $1, $2) }
    funcs.close = { closefn($0) }
    let result = fopencookie(buffer, "wb", funcs)
#error("TODO: fopencookie()")
#endif

    // Set buffering for the new file to match the typical settings for these
    // streams on POSIX systems.
    switch stream {
    case .standardOutput:
      _ = setvbuf(result, nil, _IOLBF, Int(BUFSIZ))
    case .standardError:
      _ = setvbuf(result, nil, _IONBF, Int(BUFSIZ))
    }

    return result
  }

  /// Append the given bytes to this instance's internal buffer and, when
  /// appropriate, post corresponding events.
  ///
  /// - Parameters:
  ///   - bytes: A pointer to the first byte to append.
  ///   - count: How many bytes to append.
  mutating func append(_ bytes: UnsafePointer<CChar>, count: Int) {
    // Forward this output to the original stream.
    switch stream {
    case .standardOutput:
      _ = fwrite(bytes, 1, count, originalStandardOutput)
    case .standardError:
      _ = fwrite(bytes, 1, count, originalStandardError)
    }

    _buffer.append(contentsOf: UnsafeBufferPointer(start: bytes, count: count))
    while let index = _buffer.firstIndex(of: 10 /* \n */) {
      defer {
        _buffer.removeSubrange(_buffer.startIndex ... index)
      }

      // Convert the line into a Swift string.
      _buffer[index] = 0
      let line = _buffer[..<index].withUnsafeBufferPointer { line in
        String(validatingUTF8: line.baseAddress!)
      }
      if let line {
        Event.post(.messagePrinted(line, stream: stream))
      }
    }
  }
}

/// The original `stdout` stream.
///
/// Getting the value of this property will trigger installation of the listener
/// stream if it hasn't been installed already.
let originalStandardOutput = swt_set_stdout(_ListenerStream.funopen(as: .standardOutput))

/// The original `stderr` stream.
///
/// Getting the value of this property will trigger installation of the listener
/// stream if it hasn't been installed already.
let originalStandardError = swt_set_stderr(_ListenerStream.funopen(as: .standardError))

/// Install listener streams in place of `stdout` and `stderr` that post test
/// events when lines of text are written to either of those streams.
///
/// The effect of this function is platform-dependent.
///
/// For platforms that use file descriptors (Darwin, Linux, etc.), the listener
/// streams are not able to observe output written directly to `STDOUT_FILENO`
/// or `STDERR_FILENO` (or a duplicate of either.)
///
/// This function has no effect on Windows, where there is no equivalent of
/// `funopen()` or `fopencookie()`.
func startListeningForStandardIO() {
  _ = originalStandardOutput
  _ = originalStandardError
}
#elseif os(Windows)
/// The original `stdout` stream.
var originalStandardOutput: SWT_FILEHandle {
  swt_stdout()
}

/// The original `stderr` stream.
var originalStandardError: SWT_FILEHandle {
  swt_stderr()
}

/// Install listener streams in place of `stdout` and `stderr` that post test
/// events when lines of text are written to either of those streams.
///
/// This function has no effect on this platform.
func startListeningForStandardIO() {}
#endif
#endif
