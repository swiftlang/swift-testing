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
      /// The suspending-clock time corresponding to this instant.
      fileprivate(set) var suspending = TimeValue(SuspendingClock.Instant.now)

#if !SWT_NO_UTC_CLOCK
      /// The wall-clock time corresponding to this instant.
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

      /// The current time according to the testing clock.
      public static var now: Self {
        Self()
      }
    }

    public init() {}
  }
}

// MARK: -

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

extension Test.Clock.Instant {
#if !SWT_NO_UTC_CLOCK
  /// The duration since 1970 represented by this instance.
  ///
  /// The value of this property is the equivalent of `self` on the wall clock.
  /// It is suitable for display to the user, but not for fine timing
  /// calculations.
  public var durationSince1970: Duration {
    wall.rawValue
  }
#endif
}

// MARK: - Clock

extension Test.Clock: _Concurrency.Clock {
  public typealias Duration = SuspendingClock.Duration

  public var now: Instant {
    .now
  }

  public var minimumResolution: Duration {
    SuspendingClock().minimumResolution
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
#if !SWT_NO_UNSTRUCTURED_TASKS
    return try await SuspendingClock().sleep(for: duration)
#elseif !SWT_NO_TIMESPEC
    var ts = timespec(tv_sec: .init(duration.components.seconds), tv_nsec: .init(duration.components.attoseconds / 1_000_000_000))
    var tsRemaining = ts
    while 0 != nanosleep(&ts, &tsRemaining) {
      try Task.checkCancellation()
      ts = tsRemaining
    }
#else
#warning("Platform-specific implementation missing: task sleep unavailable")
#endif
  }

  public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
    let duration = Instant.now.duration(to: deadline)
#if SWT_NO_UNSTRUCTURED_TASKS
    try await Self.sleep(for: duration)
#else
    try await SuspendingClock().sleep(for: duration, tolerance: tolerance)
#endif
  }
}

// MARK: - Equatable, Hashable, Comparable

extension Test.Clock.Instant: Equatable, Hashable, Comparable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.suspending == rhs.suspending
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(suspending)
  }

  public static func <(lhs: Self, rhs: Self) -> Bool {
    lhs.suspending < rhs.suspending
  }
}

// MARK: - InstantProtocol

extension Test.Clock.Instant: InstantProtocol {
  public typealias Duration = Swift.Duration

  public func advanced(by duration: Duration) -> Self {
    var result = self

    result.suspending = TimeValue(rawValue: result.suspending.rawValue + duration)
#if !SWT_NO_UTC_CLOCK
    result.wall = TimeValue(rawValue: result.wall.rawValue + duration)
#endif

    return result
  }

  public func duration(to other: Test.Clock.Instant) -> Duration {
    other.suspending.rawValue - suspending.rawValue
  }
}

#if !SWT_NO_SNAPSHOT_TYPES
// MARK: - Codable

extension Test.Clock.Instant: Codable {}
#endif
