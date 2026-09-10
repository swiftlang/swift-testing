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
