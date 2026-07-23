//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_ABI_JSON_SCHEMA
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
    var absolute: Double?

    /// The number of seconds since the UNIX epoch (1970-01-01 00:00:00 UT).
    package var since1970: Double?
  }
}

// MARK: - Conversion to/from library types

extension ABI.EncodedInstant {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - instant: The instant to initialize this instance from.
  public init(encoding instant: borrowing Test.Clock.Instant) {
#if !SWT_NO_SUSPENDING_CLOCK
    absolute = instant.suspending.rawValue / .seconds(1)
#endif
#if !SWT_NO_UTC_CLOCK
    since1970 = instant.wall.rawValue / .seconds(1)
#endif
  }
}

#if !SWT_NO_ABI_JSON_SCHEMA
@_spi(ForToolsIntegrationOnly)
extension Test.Clock.Instant {
  /// Initialize this instant to be exactly equal to an instant from the testing
  /// library's event stream.
  ///
  /// - Parameters:
  ///   - instant: The encoded instant to initialize this instant from.
  ///
  /// @Comment {
  ///   If `instant` omits either the suspending-clock value or the wall-clock
  ///   value, that value is synthesized from the current system's clock.
  /// }
  ///
  /// - Note: When the original instant is encoded to the event stream,
  ///   it loses some precision.
  public init?<V>(decoding instant: ABI.EncodedInstant<V>) {
    // It's not really an experimental "field", but only synthesize absolute or
    // since1970 if they're enabled as the current schema requires both values.
    if !V.includesExperimentalFields, instant.absolute == nil || instant.since1970 == nil {
      return nil
    }

    switch (instant.absolute, instant.since1970) {
    case let (.some(absolute), .some(since1970)):
      let suspending = TimeValue(rawValue: .seconds(absolute))
      let wall = TimeValue(rawValue: .seconds(since1970))
#if !SWT_NO_SUSPENDING_CLOCK && !SWT_NO_UTC_CLOCK
      self.init(suspending: suspending, wall: wall)
#elseif !SWT_NO_SUSPENDING_CLOCK
      self.init(suspending: suspending)
#elseif !SWT_NO_UTC_CLOCK
      self.init(wall: wall)
#else
      self.init()
#endif
#if !SWT_NO_SUSPENDING_CLOCK
    case let (.some(absolute), _):
      let effectiveEpoch = Test.Clock().systemEpoch
      let offset = .seconds(absolute) - effectiveEpoch.suspending.rawValue
      self = effectiveEpoch.advanced(by: offset)
#endif
#if !SWT_NO_UTC_CLOCK
    case let (_, .some(since1970)):
      let effectiveEpoch = Test.Clock().systemEpoch
      let offset = .seconds(since1970) - effectiveEpoch.wall.rawValue
      self = effectiveEpoch.advanced(by: offset)
#endif
    default:
      // Neither value was encoded (or the sole encoded value isn't supported on
      // this system). Assume the timestamp is 1:1 with the current system's
      // clock (i.e. events are delivered, encoded, and decoded with zero latency).
      self = .now
    }
  }
}
#endif

#if !SWT_NO_SUSPENDING_CLOCK
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
    guard let instant = Test.Clock.Instant(decoding: instant) else {
      return nil
    }
    self.init(instant)
  }
}
#endif

// Date.init(decoding:) is in the Foundation overlay.

// MARK: - Codable

extension ABI.EncodedInstant: Codable {}
#endif
