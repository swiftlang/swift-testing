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

/// Writes a Swift string as UTF-8 to the current system's console.
///
/// - Parameters:
///   - string: The string to write.
///
/// The testing library uses this function to write a _human-readable_
/// transcript of a test run. This function is a convenience over
/// `_swift_testing_writeToConsole()`, which Platform Abstraction Layer authors
/// must implement instead of this function.
@inline(always) func _swift_testing_writeToConsole(_ string: String) {
#if !hasFeature(Embedded)
#if !SWT_NO_FILE_IO
  try? FileHandle.stderr.write(string)
#else
  // TODO: determine whether we can reliably call `print()` here or something else
#endif
#else
  var string = string
  string.withUTF8 { string in
    if let baseAddress = string.baseAddress {
      _swift_testing_writeToConsole(baseAddress, string.count)
    }
  }
#endif
}

#if hasFeature(Embedded)
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
@inline(always) func _swift_exit(_ exitCode: CInt) -> Never {
#if !hasFeature(Embedded)
  _TestingInternals.exit(exitCode)
#else
  _swift_exit(exitCode) as Void
  swt_unreachable()
#endif
}
