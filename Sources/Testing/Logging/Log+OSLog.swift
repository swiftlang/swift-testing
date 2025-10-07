//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && canImport(os.log)
private import _TestingInternals

extension Test.Log {
  /// The previously-set `os_log` callback function, if any.
  ///
  /// The first time this value is read, the setter atomically updates the value
  /// stored in the logging library to the testing library's callback.
  private static let _oldCallback: _os_log_callback? = {
    if #available(macOS 13, *) {
      os_log_set_test_callback(_handle)
    } else {
      os_log_set_fault_callback(_handle)
    }
  }()

  /// Start listening for messages from `os_log`.
  ///
  /// Call ``startListening()`` instead of this function. Calling this function
  /// more than once has no effect.
  static func startListeningForOSLogMessages() {
    _ = _oldCallback
  }

  /// The `os_log` message handler.
  private static let _handle: _os_log_callback = { info in
    defer {
      _oldCallback?(info)
    }

    // Don't recursively call into this function.
    if swt_isHandlingOSLogMessage {
      return
    }
    swt_isHandlingOSLogMessage = true
    defer {
      swt_isHandlingOSLogMessage = false
    }

    guard let stringValue = String(validatingCString: info.pointee.message) else {
      return
    }

    // Map the message level to an issue severity level. Note that os_log does
    // not have a "warning" level.
    var severity: Issue.Severity? = nil
    if info.pointee.type.rawValue >= OSLogType.error.rawValue {
      severity = .error
    }

    let sourceContext = SourceContext(
      backtrace: Backtrace(addresses: CollectionOfOne(info.pointee.pc as Optional)),
      sourceLocation: nil
    )

    Test.Log.record(stringValue, severity: severity, sourceContext: sourceContext)
  }
}
#endif
