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
import _Concurrency

@c @implementation func _swift_testing_getEmbeddedTargetInfo() -> UnsafePointer<CChar>? {
  return UnsafePointer(strdup("Wherever Jonathan Is")!)
}

@c @implementation func _swift_testing_getTimeSinceSystemEpoch(_ outSeconds: UnsafeMutablePointer<UInt32>, _ outNanoseconds: UnsafeMutablePointer<UInt32>) -> CBool {
  var ts = timespec()
  clock_gettime(CLOCK_MONOTONIC, &ts)
  outSeconds.pointee = UInt32(ts.tv_sec)
  outNanoseconds.pointee = UInt32(ts.tv_nsec)
  return true
}

@c @implementation func _swift_testing_writeToConsole(_ chars: UnsafePointer<UInt8>, _ count: Int) {
  for i in 0 ..< count {
    putchar(CInt(chars[i]))
  }
}

@c @implementation func _swift_testing_getConsoleCapabilities(_ outConsoleCapabilities: UnsafeMutablePointer<swift_testing_console_capabilities_t>) -> CBool {
  false
}


/// This file contains abstractions over functionality that, under Embedded
/// Swift, is provided by Swift Testing's Platform Abstraction Layer annex.

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
