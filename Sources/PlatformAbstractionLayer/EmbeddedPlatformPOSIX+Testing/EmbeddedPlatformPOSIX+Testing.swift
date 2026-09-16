//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if hasFeature(Embedded)
private import Testing
private import _TestingInternals

/// The value returned by `_swift_testing_getEmbeddedTargetInfo()`.
private nonisolated(unsafe) let _embeddedTargetInfo: UnsafePointer<CChar>? = {
  Testing.uname().flatMap { strdup($0) }
}()

@c @implementation func _swift_testing_getEmbeddedTargetInfo() -> UnsafePointer<CChar>? {
  _embeddedTargetInfo
}

@c @implementation func _swift_testing_getTimeSinceSystemEpoch(_ outSeconds: UnsafeMutablePointer<UInt32>, _ outNanoseconds: UnsafeMutablePointer<UInt32>) -> CBool {
  var ts = timespec()
  // FIXME: strictly speaking, CLOCK_MONOTONIC is incorrect on Darwin and on
  // Linux, but SWT_TARGET_OS_APPLE and os(Linux) don't work as we want in
  // Embedded Swift (there's no OS as far as the compiler is concerned).
  clock_gettime(CLOCK_MONOTONIC, &ts)
  outSeconds.pointee = UInt32(ts.tv_sec)
  outNanoseconds.pointee = UInt32(ts.tv_nsec)
  return true
}

@c @implementation func _swift_testing_writeToConsole(_ chars: UnsafePointer<UInt8>, _ count: Int) {
  _ = fwrite(chars, 1, count, swt_stderr())
}

@c @implementation func _swift_testing_getConsoleCapabilities(_ outConsoleCapabilities: UnsafeMutablePointer<swift_testing_console_capabilities_t>) -> CBool {
  false
}
#endif
