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

/// This file contains implementations of Swift Testing's Platform Abstraction
/// Layer annex for use with non-Embedded Swift targets.
///
/// If you have a custom build workflow and define these functions elsewhere,
/// define `SWT_NO_PAL_ANNEX` to suppress this implementation.

#if !hasFeature(Embedded)
#if !SWT_NO_PAL_ANNEX
// MARK: - Stubs replicating the core PAL
@c func _swift_exit(_ exitCode: CInt) {
  exit(exitCode)
}

// MARK: - Test discovery

@available(*, unavailable) // intentionally not @c @implementation
func _swift_testing_getTestSectionBounds(_ outBegin: UnsafeMutablePointer<UnsafeRawPointer?>, _ outEnd: UnsafeMutablePointer<UnsafeRawPointer?>) -> CBool {
  false
}

// MARK: - System information

@available(*, unavailable) // intentionally not @c @implementation
func _swift_testing_getEmbeddedSwiftTarget() -> UnsafePointer<CChar>? {
  nil
}

// MARK: - Console output

#if !SWT_NO_FILE_IO
@available(*, unavailable) // intentionally not @c @implementation
#else
@c @implementation
#endif
func _swift_testing_getConsoleCapabilities(_ outConsoleCapabilities: UnsafeMutablePointer<SWTConsoleCapabilities>) -> CBool {
  false
}

@c @implementation func _swift_testing_writeToConsole(_ chars: UnsafePointer<UInt8>, _ count: Int) {
  let buffer = UnsafeBufferPointer<UInt8>(start: chars, count: count)
#if !SWT_NO_FILE_IO
  try? FileHandle.stderr.write(buffer)
#else
  // The platform should still have some `print()` implementation.
  // TODO: determine if we need a further fallback or an availability check here
  if let string = String(validating: buffer, as: UTF8.self) {
    print(string, terminator: "")
  }
#endif
}

// MARK: - JSON output

@available(*, unavailable) // intentionally not @c @implementation
func _swift_testing_writeJSON(_ json: UnsafePointer<UInt8>, _ count: Int, _ terminator: UnsafePointer<UInt8>?) {}
#endif
#else
// MARK: - Forwards from the core PAL

@_extern(c) func _swift_exit(_ exitCode: CInt)
#endif

// MARK: - Common abstractions

/// Writes a Swift string as UTF-8 to the current system's console.
///
/// - Parameters:
///   - string: The string to write.
///
/// The testing library uses this function to write a _human-readable_
/// transcript of a test run. This function is a convenience over
/// `_swift_testing_writeToConsole()`, which PAL authors must implement instead
/// of this function.
@inline(always) func _swift_testing_writeToConsole(_ string: String) {
  var string = string
  string.withUTF8 { string in
    if let baseAddress = string.baseAddress {
      _swift_testing_writeToConsole(baseAddress, string.count)
    }
  }
}
