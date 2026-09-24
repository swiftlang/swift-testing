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

#if canImport(Synchronization)
private import Synchronization
#endif

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

// MARK: -

#if hasFeature(Embedded) && !SWT_NO_ABI_JSON_SCHEMA
extension JSON {
  /// Storage for ``embeddedFileDescriptor``.
  private static let _embeddedFileDescriptor = Atomic<CInt>(-1)

  /// The file descriptor to which JSON should be written.
  ///
  /// If this property's value is not `nil`, then when the testing library calls
  /// `_swift_testing_writeJSON()` (and that function is implemented by one of
  /// our reference implementations), that function writes the provided JSON
  /// bytes to the represented file descriptor.
  ///
  /// - Important: If the value of this property is not `nil`, then the
  ///   represented file descriptor must remain open and writable for the
  ///   lifetime of the current process.
  static var embeddedFileDescriptor: CInt? {
    @_silgen_name("_swift_testing_getEmbeddedJSONFileDescriptor") get {
      let fd = _embeddedFileDescriptor.load(ordering: .sequentiallyConsistent)
      return fd >= 0 ? fd : nil
    }
    set {
      _embeddedFileDescriptor.store(newValue ?? -1, ordering: .sequentiallyConsistent)
    }
  }
}
#endif
