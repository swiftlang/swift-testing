//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABIv0 {
  /// A type implementing the JSON encoding of ``Test/Clock/Instant`` for the
  /// ABI entry point and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedInstant: Sendable {
    /// The number of seconds since the system-defined suspending epoch.
    ///
    /// For more information, see [`SuspendingClock`](https://developer.apple.com/documentation/swift/suspendingclock).
    var absolute: Double

    /// The number of seconds since the UNIX epoch (1970-01-01 00:00:00 UT).
    var since1970: Double

    init(encoding instant: borrowing Test.Clock.Instant) {
      absolute = Double(instant.suspending)
#if !SWT_NO_UTC_CLOCK
      since1970 = Double(instant.wall)
#else
      since1970 = 0
#endif
    }
  }
}

// MARK: - Codable

extension ABIv0.EncodedInstant: Codable {}
