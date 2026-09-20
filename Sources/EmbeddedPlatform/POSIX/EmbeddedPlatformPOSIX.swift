//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

#if canImport(Synchronization)
private import Synchronization
#endif

#if hasFeature(Embedded)
/// A structure that stores the `argc` and `argv` values we capture when the
/// process starts.
private struct _ArgcArgv: Sendable, RawRepresentable {
  nonisolated(unsafe) var rawValue = UnsafeMutableBufferPointer<UnsafeMutablePointer<CChar>>(start: nil, count: 0)
}

/// Storage for `_swift_testing_getArgcArgv()`.
private let _argcArgv = Mutex(_ArgcArgv())

/// A constructor function that is called automatically, which we use to capture
/// the early values of `argc` and `argv` where available.
@section(".init_array.65535") @used
private let _captureArgcArgv: @convention(c) (CInt, UnsafeMutablePointer<UnsafeMutablePointer<CChar>>?, UnsafeRawPointer) -> Void = { argc, argv, _ in
  guard swt_isGNUCLibrary() else {
    // The arguments to this function are non-standard and provided when using
    // the GNU C Library only.
    return
  }

  guard argc > 0, let argv else {
    // Nothing to store.
    return
  }

  // Do a deep copy of `argv` as the original pointer may be mutated, freed, or
  // otherwise unpreserved by the time we need it.
  let argvCopy = UnsafeMutableBufferPointer<UnsafeMutablePointer<CChar>>.allocate(capacity: Int(clamping: argc))
  for i in 0 ..< argvCopy.count {
    argvCopy[i] = strdup(argv[i])!
  }
  _argcArgv.withLock { argcArgv in
    argcArgv.rawValue = argvCopy
  }
}

@c @implementation func _swift_testing_getArgcArgv(_ outArgc: UnsafeMutablePointer<CInt>, _ outArgv: UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>>?>) -> CBool {
  guard swt_isGNUCLibrary() else {
    return false
  }

  let argcArgv = _argcArgv.withLock { $0 }.rawValue
  if argcArgv.isEmpty {
    return false
  }

  outArgc.initialize(to: CInt(clamping: argcArgv.count))
  outArgv.initialize(to: argcArgv.baseAddress!)
  return true
}

@c @implementation func _swift_testing_getEnvironment(_ outEnvironment: UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>) -> CBool {
  outEnvironment.initialize(to: swt_environ())
  return true
}

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

@c @implementation func _swift_testing_getEmbeddedTargetInfo() -> UnsafePointer<CChar>? {
  UnsafePointer(_embeddedTargetInfo)
}

#if !SWT_NO_FILE_IO
/// Get the console capabilities for the given file handle.
///
/// This declaration is provided because this module does not directly link to
/// the testing library.
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

@c func _swift_testing_writeJSON(_ json: UnsafePointer<UInt8>, _ count: Int, _ terminator: UnsafePointer<UInt8>?) {
  // TODO: allow POSIX-compliant configuration of the target for JSON (e.g. a file descriptor)
}

@c @implementation func _swift_testing_getTimeSinceSystemEpoch(_ outSeconds: UnsafeMutablePointer<UInt32>, _ outNanoseconds: UnsafeMutablePointer<UInt32>) -> CBool {
  var ts = timespec()
  clock_gettime(CLOCK_MONOTONIC, &ts)
  outSeconds.pointee = UInt32(clamping: ts.tv_sec)
  outNanoseconds.pointee = UInt32(clamping: ts.tv_nsec)
  return true
}
#endif
