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
private let _argcArgv: swift_testing_argc_argv_t = {
  var argc = 0
  var argvByteCount = 0
  guard 0 == __wasi_args_sizes_get(&argc, &argvByteCount), argc > 0, argvByteCount > 0 else {
    return swift_testing_argc_argv_t()
  }

  let argv = UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: argc)
  let argvBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: argvByteCount)
  guard 0 == __wasi_args_get(argv.baseAddress!, argvBuffer.baseAddress!) else {
    return swift_testing_argc_argv_t()
  }

  return swift_testing_argc_argv_t(
    argc: CInt(clamping: argc),
    argv: UnsafeMutableRawBufferPointer(argv)
      .assumingMemoryBound(to: UnsafeMutablePointer<CChar>.self)
      .baseAddress!
  )
}()

@c @implementation func _swift_testing_getArgcArgv(_ outArgcArgv: UnsafeMutablePointer<swift_testing_argc_argv_t>) -> CBool {
  outArgcArgv.initialize(to: _argcArgv)
  return true
}

#if !SWT_NO_ENVIRONMENT_VARIABLES
@c @implementation func _swift_testing_getEnvironment(_ outEnvironment: UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>) -> CBool {
  outEnvironment.initialize(to: __wasilibc_get_environ())
  return true
}
#endif

@c @implementation func _swift_testing_getEmbeddedTargetInfo(_ outEmbeddedTargetInfo: UnsafeMutablePointer<UnsafePointer<CChar>?>) -> CBool {
  false
}

@c @implementation func _swift_testing_getConsoleCapabilities(_ outConsoleCapabilities: UnsafeMutablePointer<swift_testing_console_capabilities_t>) -> CBool {
  false
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

@c @implementation func _swift_testing_writeJSON(_ json: UnsafePointer<UInt8>, _ count: Int, _ terminator: UnsafePointer<UInt8>?) {
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
