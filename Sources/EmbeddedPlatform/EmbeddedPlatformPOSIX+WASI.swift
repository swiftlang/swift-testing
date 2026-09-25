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
@c @implementation func _swift_testing_writeJSON(_ destination: UnsafePointer<CChar>?, _ json: UnsafePointer<UInt8>, _ count: Int, _ terminator: UnsafePointer<UInt8>?) {
  // This implementation does not define a "default" JSON destination.
  guard let path else {
    return
  }

  // To avoid maintaining a mapping of paths to files, this implementation only
  // supports writing to the /dev/fd/ virtual filesystem.
  var fd: CInt = -1
  if 0 == strcmp(path, "/dev/stdout") {
    fd = STDOUT_FILENO
  } else if 0 == strcmp(path, "/dev/stderr") {
    fd = STDERR_FILENO
  } else {
    let scannedFD = withUnsafeMutablePointer(to: &fd) { fd in
      withVaList([fd]) { 1 == vsscanf(path, "/dev/fd/%d", $0) }
    }
    guard scannedFD else {
      return
    }
  }
  guard fd >= 0 else {
    return
  }

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
