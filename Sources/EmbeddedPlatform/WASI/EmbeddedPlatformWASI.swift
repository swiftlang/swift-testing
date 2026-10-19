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
#endif
