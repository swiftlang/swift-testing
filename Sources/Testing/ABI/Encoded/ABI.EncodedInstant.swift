//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABI {
  /// A type implementing the JSON encoding of ``Test/Clock/Instant`` for the
  /// ABI entry point and event stream output.
  ///
  /// You can use this type and its conformance to [`Codable`](https://developer.apple.com/documentation/swift/codable),
  /// when integrating the testing library with development tools. It is not
  /// part of the testing library's public interface.
  public struct EncodedInstant<V>: Sendable where V: ABI.Version {
    /// The number of seconds since the system-defined suspending epoch.
    ///
    /// For more information, see [`SuspendingClock`](https://developer.apple.com/documentation/swift/suspendingclock).
    var absolute: Double

    /// The number of seconds since the UNIX epoch (1970-01-01 00:00:00 UT).
    package var since1970: Double
  }
}

// MARK: - Conversion to/from library types

extension ABI.EncodedInstant {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - instant: The instant to initialize this instance from.
  public init(encoding instant: borrowing Test.Clock.Instant) {
    absolute = Double(instant.suspending)
#if !SWT_NO_UTC_CLOCK
    since1970 = Double(instant.wall)
#else
    since1970 = 0
#endif
  }
}

@_spi(ForToolsIntegrationOnly)
extension SuspendingClock.Instant {
  /// Initialize this instant to equal an instant from the testing library's
  /// event stream.
  ///
  /// - Parameters:
  ///   - instant: The encoded instant to initialize this instance from.
  ///
  /// The resulting instance is equivalent to the suspending-clock time
  /// represented by `instant`.
  public init?<V>(decoding instant: ABI.EncodedInstant<V>) {
    self.init(TimeValue(instant.absolute))
  }
}

// Date.init(decoding:) is in the Foundation overlay.

// MARK: - Codable

extension ABI.EncodedInstant: Codable {}
