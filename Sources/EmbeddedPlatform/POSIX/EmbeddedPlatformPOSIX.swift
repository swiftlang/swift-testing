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
            var result: UnsafeMutablePointer<CChar>?
            _ = vasprintf(&result, "%s (%s)", args)
            return result
          }
        }
      }
    }
  }
}()

@c @implementation func _swift_testing_getEmbeddedTargetInfo() -> UnsafePointer<CChar>? {
  UnsafePointer(_embeddedTargetInfo)
}

@c @implementation func _swift_testing_getConsoleCapabilities(_ outConsoleCapabilities: UnsafeMutablePointer<swift_testing_console_capabilities_t>) -> CBool {
  false
}

@c @implementation func _swift_testing_writeToConsole(_ chars: UnsafePointer<UInt8>, _ count: Int) {
  fwrite(chars, 1, count, swt_stderr())
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
