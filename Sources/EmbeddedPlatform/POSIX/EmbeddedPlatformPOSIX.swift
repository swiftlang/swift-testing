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

#if hasFeature(Embedded)
/// Storage for `_swift_testing_getArgcArgv()`.
private let _argcArgv = Mutex(swift_testing_argc_argv_t())

/// A constructor function that is called automatically, which we use to capture
/// the early values of `argc` and `argv` where available.
@section(".init_array.65535") @used
private let _captureArgcArgv: @convention(c) (CInt, UnsafeMutablePointer<UnsafeMutablePointer<CChar>>?, UnsafeRawPointer?) -> Void = { argc, argv, _ in
  guard swt_isGNUCLibrary() else {
    // The arguments to this function are non-standard and provided when using
    // the GNU C Library only.
    return
  }

  guard argc > 0, let argv else {
    // Nothing to store.
    return
  }

  if argc > 0, let argv {
    let argcArgv = swift_testing_argc_argv_t(argc: argc, argv: argv)
    _argcArgv.withLock { $0 = argcArgv }
  }
}

@c @implementation func _swift_testing_getArgcArgv(_ outArgcArgv: UnsafeMutablePointer<swift_testing_argc_argv_t>) -> CBool {
  guard swt_isGNUCLibrary() else {
    return false
  }

  let argcArgv = _argcArgv.withLock { $0 }
  guard let argcArgv else {
    return false
  }
  outArgcArgv.initialize(to: argcArgv)
  return true
}

#if !SWT_NO_ENVIRONMENT_VARIABLES
@c @implementation func _swift_testing_getEnvironment(_ outEnvironment: UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>) -> CBool {
  outEnvironment.initialize(to: swt_environ())
  return true
}
#endif

/// Storage for `_swift_testing_getEmbeddedTargetInfo()`.
private nonisolated(unsafe) let _embeddedTargetInfo: UnsafeMutablePointer<CChar>? = {
  var name = utsname()
  guard 0 == uname(&name) else {
    return nil
  }

  return withUnsafeBytes(of: name.release) { release in
    release.withMemoryRebound(to: CChar.self) { release in
      withUnsafeBytes(of: name.version) { version in
        version.withMemoryRebound(to: CChar.self) { version in
          withVaList([release.baseAddress!, version.baseAddress!]) { args in
            withUnsafeTemporaryAllocation(of: CChar.self, capacity: release.count + version.count + 16) { buffer in
              _ = vsnprintf(buffer.baseAddress!, buffer.count, "%s (%s)", args)
              return strdup(buffer.baseAddress!)
            }
          }
        }
      }
    }
  }
}()

@c @implementation func _swift_testing_getEmbeddedTargetInfo(_ outEmbeddedTargetInfo: UnsafeMutablePointer<UnsafePointer<CChar>?>) -> CBool {
  outEmbeddedTargetInfo.initialize(to: _embeddedTargetInfo)
  return _embeddedTargetInfo != nil
}

#if !SWT_NO_FILE_IO
/// Get the console capabilities for the given file handle.
///
/// This declaration is provided because this module does not directly link to
/// the testing library. For more information, see the declaration of this
/// symbol in the main testing library target.
@_extern(c) private func _swift_testing_getConsoleCapabilitiesForFILE(
  _ fileHandle: SWT_FILEHandle,
  _ outConsoleCapabilities: UnsafeMutablePointer<swift_testing_console_capabilities_t>
) -> CBool
#endif

@c @implementation func _swift_testing_getConsoleCapabilities(_ outConsoleCapabilities: UnsafeMutablePointer<swift_testing_console_capabilities_t>) -> CBool {
#if !SWT_NO_FILE_IO
  _swift_testing_getConsoleCapabilitiesForFILE(swt_stderr(), outConsoleCapabilities)
#else
  false
#endif
}

@c @implementation func _swift_testing_writeToConsole(_ chars: UnsafePointer<UInt8>, _ count: Int) {
  write(STDERR_FILENO, chars, count)
}

#if !SWT_NO_ABI_JSON_SCHEMA
private enum JSON {
  /// The file descriptor to which JSON should be written.
  ///
  /// This declaration is provided because this module does not directly link to
  /// the testing library. For more information, see the declaration of this
  /// symbol in the main testing library target.
  static var embeddedFileDescriptor: CInt? {
    @_silgen_name("_swift_testing_getEmbeddedJSONFileDescriptor") get
  }
}

@c func _swift_testing_writeJSON(_ json: UnsafePointer<UInt8>, _ count: Int, _ terminator: UnsafePointer<UInt8>?) {
  guard let fd = JSON.embeddedFileDescriptor else {
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
