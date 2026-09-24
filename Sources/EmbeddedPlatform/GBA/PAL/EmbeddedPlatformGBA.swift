#if hasFeature(Embedded)

internal import _TestingInternals
import libc
import tonc

// MARK: - swift-testing Platform Abstraction Layer
//
// These implement the functions declared in swift-testing's
// Sources/_TestingInternals/include/EmbeddedPlatform.h.

/// Sets up the hardware for a test run.
private func _initialize() {
  irq_init(nil)
  irq_enable(II_VBLANK)

  // swift-testing calls `exit()` when the run finishes. Keep the results on
  // screen instead of returning to crt0.
  atexit {
    while true {
      VBlankIntrWait()
    }
  }
}

@c @implementation func _swift_testing_getArgcArgv(_ outArgcArgv: UnsafeMutablePointer<swift_testing_argc_argv_t>) -> CBool {
  _initialize()
  return false
}

@c @implementation func _swift_testing_getEnvironment(_ outEnvironment: UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>) -> CBool {
  false
}

@c @implementation func _swift_testing_getEmbeddedTargetInfo(_ outEmbeddedTargetInfo: UnsafeMutablePointer<UnsafePointer<CChar>?>) -> CBool {
  outEmbeddedTargetInfo.pointee = UnsafePointer(strdup("Game Boy Advance (ARM7TDMI)")!)
  return true
}

@c @implementation func _swift_testing_getConsoleCapabilities(_ outConsoleCapabilities: UnsafeMutablePointer<swift_testing_console_capabilities_t>) -> CBool {
  // Plain text only
  false
}

@c @implementation func _swift_testing_writeToConsole(_ chars: UnsafePointer<UInt8>, _ count: Int) {
  fwrite(chars, 1, count, stdout)
}

@c @implementation func _swift_testing_writeJSON(_ json: UnsafePointer<UInt8>, _ count: Int, _ terminator: UnsafePointer<UInt8>?) {
  // There's nowhere to send the JSON event stream.
}

@c @implementation func _swift_testing_getDurationSinceSystemEpoch(_ outDuration: UnsafeMutablePointer<swift_testing_duration_t>) -> CBool {
  var ts = timespec()
  guard clock_gettime(CLOCK_MONOTONIC, &ts) == 0 else {
    return false
  }
  outDuration.initialize(
    to: swift_testing_duration_t(
      seconds: UInt32(clamping: ts.tv_sec),
      nanoseconds: UInt32(clamping: ts.tv_nsec)
    )
  )
  return true
}

#endif
