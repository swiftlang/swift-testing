//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// Report a message to the testing library that was logged in an external
/// logging system such as `os_log`.
///
/// - Parameters:
///   - message: The message to log as a null-terminated UTF-8 string.
///   - severity: The severity of the message. The following values are
///     currently recognized:
///     - `0`: Default (no) severity.
///     - `1`: Warning severity.
///     - `2`: Error severity.
///   - backtraceSymbols: A pointer to an array of call stack addresses
///     representing a backtrace at the time the messaged was logged. If this
///     information is not available, pass `nil`.
///   - backtraceSymbolCount: The number of call stack addresses at
///     `backtraceSymbols`. If this information is not available, pass `0`.
///   - fileID: The file ID where the message originated as a null-terminated
///     UTF-8 string. If this information is not available, pass `nil`.
///   - filePath: The file path where the message originated as a
///     null-terminated UTF-8 string. If this information is not available, pass
///     `nil`.
///   - line: The line where the message originated. If this information is not
///     available, pass `0`.
///   - column: The column where the message originated. If this information is
///     not available, pass `0`.
///   - reserved: Reserved for future use. Pass `nil`.
///
/// External logging systems can call this function in order to insert their
/// logged messages into the output of the testing library's test run. This
/// function is exported with the following C function signature:
///
/// ```c
/// extern void swift_testing_messageLogged(
///   const char *message,
///   int severity,
///   const void *_Nullable reserved
/// );
/// ```
@_cdecl("swift_testing_messageLogged")
@usableFromInline
func swift_testing_messageLogged(
  _ message: UnsafePointer<CChar>,
  _ severity: CInt,
  _ reserved: UnsafeRawPointer?
) {
  guard let stringValue = String(validatingCString: message) else {
    return
  }

  // Map the `severity` integer value to an issue severity level.
  let severity: Issue.Severity? = switch severity {
  case 1:
    .warning
  case 2:
    .error
  default:
    nil // 0 or an unsupported/unrecognized value.
  }

  Test.Log.record(
    stringValue,
    severity: severity,
    sourceContext: SourceContext(backtrace: .current(), sourceLocation: nil)
  )
}
