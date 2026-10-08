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

#if hasFeature(Embedded)
@c @implementation func _swift_testing_writeToConsole(_ chars: UnsafePointer<UInt8>, _ count: Int) {
  write(STDERR_FILENO, chars, count)
}

#if !SWT_NO_ABI_JSON_SCHEMA
/// A type containing the implementation-specific state for a JSON writer as
/// used by the testing library's Platform Abstraction Layer annex.
private struct _JSONWriterImpl: Sendable {
  /// The file descriptor, open for writing, to write to.
  var fd: CInt

  /// Whether or not to close `fd` when the writer is deinitialized.
  var closeOnDeinitialize: Bool
}

@c @implementation func _swift_testing_initJSONWriter(_ path: UnsafePointer<CChar>, _ outWriter: UnsafeMutablePointer<swift_testing_json_writer_t>) -> CBool {
  outWriter.withMemoryRebound(to: _JSONWriterImpl.self, capacity: 1) { outWriter in
    // Fast paths for stdout and stderr.
    if 0 == strcmp(path, "/dev/stdout") {
      outWriter.initialize(to: .init(fd: STDOUT_FILENO, closeOnDeinitialize: false))
      return true
    } else if 0 == strcmp(path, "/dev/stderr") {
      outWriter.initialize(to: .init(fd: STDERR_FILENO, closeOnDeinitialize: false))
      return true
    }

    // See if it looks like a path in the file descriptor virtual file system.
    // This isn't a standard POSIX feature, which is why we're not just
    // delegating it to the `fopen()`-based path below.
    let slashDevFD = "/dev/fd/"
    if 0 == strncmp(path, slashDevFD, strlen(slashDevFD)) {
      var end: UnsafeMutablePointer<CChar>?
      let fd = strtol(path + strlen(slashDevFD), &end, 10)
      if end?.pointee == 0, let fd = CInt(exactly: fd), fd >= 0 {
        // We were able to scan the whole string as an integer, so we will use
        // the file descriptor directly.
        outWriter.initialize(to: .init(fd: fd, closeOnDeinitialize: false))
        return true
      }
    }

    // It's a path somewhere else. Attempt to open it for writing.
    let fd = open(path, O_CREAT | O_TRUNC | O_WRONLY | O_CLOEXEC, 0o644)
    guard fd >= 0 else {
      return false
    }
    outWriter.initialize(to: .init(fd: fd, closeOnDeinitialize: true))
    return true
  }
  
}

@c @implementation func _swift_testing_writeJSON(_ writer: UnsafePointer<swift_testing_json_writer_t>, _ json: UnsafePointer<UInt8>, _ count: Int, _ terminator: UnsafePointer<UInt8>?) {
  writer.withMemoryRebound(to: _JSONWriterImpl.self, capacity: 1) { writer in
    let fd = writer.pointee.fd
    if let terminator {
      withUnsafeTemporaryAllocation(of: iovec.self, capacity: 2) { vecs in
        vecs[0] = iovec(iov_base: UnsafeMutableRawPointer(mutating: json), iov_len: count)
        vecs[1] = iovec(iov_base: UnsafeMutableRawPointer(mutating: terminator), iov_len: 1)
        writev(fd, vecs.baseAddress!, 2)
      }
    } else {
      write(fd, json, count)
    }
  }
}

@c @implementation func _swift_testing_deinitJSONWriter(_ writer: UnsafeMutablePointer<swift_testing_json_writer_t>) {
  writer.withMemoryRebound(to: _JSONWriterImpl.self, capacity: 1) { writer in
    if writer.pointee.closeOnDeinitialize {
      close(writer.pointee.fd)
    }
    writer.deinitialize(count: 1)
  }
}
#endif

@c @implementation func _swift_testing_getDurationSinceSystemEpoch(_ outDuration: UnsafeMutablePointer<swift_testing_duration_t>) -> CBool {
  var ts = timespec()
  clock_gettime(swt_CLOCK_MONOTONIC(), &ts)
  outDuration.initialize(
    to: swift_testing_duration_t(
      seconds: UInt32(clamping: ts.tv_sec),
      nanoseconds: UInt32(clamping: ts.tv_nsec)
    )
  )
  return true
}
#endif
