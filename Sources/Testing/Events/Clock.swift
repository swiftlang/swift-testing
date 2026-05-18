//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension Test {
  /// A clock used to track time when events occur during testing.
  ///
  /// This clock tracks time using both the [suspending clock](https://developer.apple.com/documentation/swift/suspendingclock)
  /// and the wall clock. Only the suspending clock is used for comparing and
  /// calculating; the wall clock is used for presentation when needed.
  public struct Clock: Sendable {
    /// An instant on the testing clock.
    public struct Instant: Sendable {
#if !SWT_NO_SUSPENDING_CLOCK
      /// The suspending-clock time corresponding to this instant.
      fileprivate(set) var suspending = TimeValue(rawValue: SuspendingClock().systemEpoch.duration(to: .now))
#endif

#if !SWT_NO_UTC_CLOCK
      /// The wall-clock time since 1970 corresponding to this instant.
      fileprivate(set) var wall: TimeValue = {
#if !SWT_NO_TIMESPEC
        var wall = timespec()
#if os(Android)
        // Android headers recommend `clock_gettime` over `timespec_get` which
        // is available with API Level 29+ for `TIME_UTC`.
        clock_gettime(CLOCK_REALTIME, &wall)
#else
        timespec_get(&wall, TIME_UTC)
#endif
        return TimeValue(rawValue: .seconds(wall.tv_sec) + .nanoseconds(wall.tv_nsec))
#else
#warning("Platform-specific implementation missing: UTC time unavailable (no timespec)")
        return TimeValue(rawValue: .zero)
#endif
      }()
#endif

      /// The time value to use for comparison with other instances of this
      /// type.
      private var _timeValueForComparison: TimeValue {
#if !SWT_NO_SUSPENDING_CLOCK
        suspending
#elseif !SWT_NO_UTC_CLOCK
        wall
#else
        TimeValue(rawValue: .zero)
#endif
      }

      /// The current time according to the testing clock.
      public static var now: Self {
        Self()
      }
    }

    public init() {}
  }
}

// MARK: -

#if !SWT_NO_SUSPENDING_CLOCK
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension SuspendingClock.Instant {
  /// Initialize this instant to the equivalent of the same instant on the
  /// testing library's clock.
  ///
  /// - Parameters:
  ///   - testClockInstant: The equivalent instant on ``Test/Clock``.
  public init(_ testClockInstant: Test.Clock.Instant) {
    self = SuspendingClock().systemEpoch + testClockInstant.suspending.rawValue
  }
}
#endif

#if !SWT_NO_ABI_JSON_SCHEMA
@_spi(ForToolsIntegrationOnly)
extension Test.Clock.Instant {
  /// Initialize this instant to be exactly equal to an instant from the testing
  /// library's event stream.
  ///
  /// - Note: When the original instant is encoded to the event stream,
  /// it loses some precision.
  ///
  /// - Parameters:
  ///   - instant: The encoded instant to initialize this instant from.
  public init?<V>(decoding instant: ABI.EncodedInstant<V>) {
#if !SWT_NO_SUSPENDING_CLOCK
    suspending = TimeValue(rawValue: .seconds(instant.absolute))
#endif
#if !SWT_NO_UTC_CLOCK
    wall = TimeValue(rawValue: .seconds(instant.since1970))
#endif
  }
}
#endif

#if !SWT_NO_UTC_CLOCK
extension Test.Clock.Instant {
  /// The duration since 1970 represented by this instance.
  ///
  /// The Foundation overlay uses this property to implement `Date.init(_:)`.
  package var durationSince1970: Duration {
    wall.rawValue
  }
}
#endif

// MARK: - Clock

extension Test.Clock: _Concurrency.Clock {
  public var now: Instant {
    .now
  }

  public var minimumResolution: Duration {
#if !SWT_NO_SUSPENDING_CLOCK
    SuspendingClock().minimumResolution
#elseif !SWT_NO_UTC_CLOCK
#if !SWT_NO_TIMESPEC
    // timespec_getres() requires C23 or newer and is not widely implemented as
    // of this writing, so we unconditionally use clock_getres() here.
    var res = timespec()
    _ = clock_getres(CLOCK_REALTIME, &res)
    return .seconds(res.tv_sec) + .nanoseconds(res.tv_nsec)
#else
#warning("Platform-specific implementation missing: UTC time unavailable (no timespec)")
    .zero
#endif
#else
    .zero
#endif
  }

  /// Suspend the current task for the given duration.
  ///
  /// - Parameters:
  ///   - duration: How long to suspend for.
  ///
  /// - Throws: `CancellationError` if the current task was cancelled while it
  ///   was sleeping.
  ///
  /// This function is not part of the public interface of the testing library.
  /// It is primarily used by the testing library's own tests. External clients
  /// can use ``sleep(for:tolerance:)`` or ``sleep(until:tolerance:)`` instead.
  static func sleep(for duration: Duration) async throws {
#if !SWT_NO_SUSPENDING_CLOCK
    return try await SuspendingClock().sleep(for: duration)
#elseif !SWT_NO_TIMESPEC
    var ts = timespec(tv_sec: .init(duration.components.seconds), tv_nsec: .init(duration.components.attoseconds / 1_000_000_000))
    var tsRemaining = ts
    while 0 != nanosleep(&ts, &tsRemaining) {
#if !hasFeature(Embedded)
      try Task.checkCancellation()
#endif
      ts = tsRemaining
    }
#else
#warning("Platform-specific implementation missing: task sleep unavailable")
#endif
  }

  public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
    let duration = Instant.now.duration(to: deadline)
#if !SWT_NO_SUSPENDING_CLOCK
    try await SuspendingClock().sleep(for: duration, tolerance: tolerance)
#else
    try await Self.sleep(for: duration)
#endif
  }
}

// MARK: - Equatable, Hashable, Comparable

extension Test.Clock.Instant: Equatable, Hashable, Comparable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs._timeValueForComparison.rawValue == rhs._timeValueForComparison.rawValue
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(_timeValueForComparison.rawValue)
  }

  public static func <(lhs: Self, rhs: Self) -> Bool {
    lhs._timeValueForComparison.rawValue < rhs._timeValueForComparison.rawValue
  }
}

// MARK: - InstantProtocol

extension Test.Clock.Instant: InstantProtocol {
  public func advanced(by duration: Duration) -> Self {
    var result = self

#if !SWT_NO_SUSPENDING_CLOCK
    result.suspending = TimeValue(rawValue: result.suspending.rawValue + duration)
#endif
#if !SWT_NO_UTC_CLOCK
    result.wall = TimeValue(rawValue: result.wall.rawValue + duration)
#endif

    return result
  }

  public func duration(to other: Test.Clock.Instant) -> Duration {
    other._timeValueForComparison.rawValue - _timeValueForComparison.rawValue
  }
}

#if !SWT_NO_SNAPSHOT_TYPES
// MARK: - Codable

extension Test.Clock.Instant: Codable {}
#endif
