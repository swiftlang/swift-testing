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
      fileprivate(set) var suspending: TimeValue = {
#if SWT_TARGET_OS_APPLE
        // The testing library's availability on Apple platforms is earlier than
        // that of the Swift Clock API, so we don't use `SuspendingClock`
        // directly on them and instead derive a value from platform-specific
        // API. SuspendingClock corresponds to CLOCK_UPTIME_RAW on Darwin.
        // SEE: https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/Clock.cpp
        var uptime = timespec()
        _ = clock_gettime(CLOCK_UPTIME_RAW, &uptime)
        return TimeValue(uptime)
#else
        /// The corresponding suspending-clock time.
        TimeValue(SuspendingClock.Instant.now)
#endif
      }()

#if !SWT_NO_UTC_CLOCK
      /// The wall-clock time corresponding to this instant.
      fileprivate(set) var wall: TimeValue = {
        var wall = timespec()
#if os(Android)
        // Android headers recommend `clock_gettime` over `timespec_get` which
        // is available with API Level 29+ for `TIME_UTC`.
        clock_gettime(CLOCK_REALTIME, &wall)
#else
        timespec_get(&wall, TIME_UTC)
#endif
        return TimeValue(wall)
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
@available(_clockAPI, *)
extension SuspendingClock.Instant {
  /// Initialize this instant to the equivalent of the same instant on the
  /// testing library's clock.
  ///
  /// - Parameters:
  ///   - testClockInstant: The equivalent instant on ``Test/Clock``.
  public init(_ testClockInstant: Test.Clock.Instant) {
    self.init(testClockInstant.suspending)
  }
}

extension Test.Clock.Instant {
#if !SWT_NO_UTC_CLOCK
  /// The duration since 1970 represented by this instance as a tuple of seconds
  /// and attoseconds.
  ///
  /// The value of this property is the equivalent of `self` on the wall clock.
  /// It is suitable for display to the user, but not for fine timing
  /// calculations.
  public var timeComponentsSince1970: (seconds: Int64, attoseconds: Int64) {
    wall.components
  }

  /// The duration since 1970 represented by this instance.
  ///
  /// The value of this property is the equivalent of `self` on the wall clock.
  /// It is suitable for display to the user, but not for fine timing
  /// calculations.
  @available(_clockAPI, *)
  public var durationSince1970: Duration {
    Duration(wall)
  }
#endif

  /// Get the number of nanoseconds from this instance to another.
  ///
  /// - Parameters:
  ///   - other: The later instant.
  ///
  /// - Returns: The number of nanoseconds between `self` and `other`. If
  ///   `other` is ordered before this instance, the result is negative.
  func nanoseconds(until other: Self) -> Int64 {
    if other < self {
      return -other.nanoseconds(until: self)
    }
    let otherNanoseconds = (other.suspending.seconds * 1_000_000_000) + (other.suspending.attoseconds / 1_000_000_000)
    let selfNanoseconds = (suspending.seconds * 1_000_000_000) + (suspending.attoseconds / 1_000_000_000)
    return otherNanoseconds - selfNanoseconds
  }
}

// MARK: - Sleeping

extension Test.Clock {
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
  @available(_clockAPI, *)
  static func sleep(for duration: Duration) async throws {
#if SWT_NO_UNSTRUCTURED_TASKS
    let timeValue = TimeValue(duration)
    var ts = timespec(timeValue)
    var tsRemaining = ts
    while 0 != nanosleep(&ts, &tsRemaining) {
      try Task.checkCancellation()
      ts = tsRemaining
    }
#else
    return try await SuspendingClock().sleep(for: duration)
#endif
  }
}

// MARK: - Clock

@available(_clockAPI, *)
extension Test.Clock: _Concurrency.Clock {
  public typealias Duration = SuspendingClock.Duration

  public var now: Instant {
    .now
  }

  public var minimumResolution: Duration {
#if SWT_TARGET_OS_APPLE
    var res = timespec()
    _ = clock_getres(CLOCK_UPTIME_RAW, &res)
    return Duration(TimeValue(res))
#else
    SuspendingClock().minimumResolution
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

@available(_clockAPI, *)
extension Test.Clock.Instant: InstantProtocol {
  public typealias Duration = Swift.Duration

  public func advanced(by duration: Duration) -> Self {
    var result = self

    result.suspending = TimeValue(Duration(result.suspending) + duration)
#if !SWT_NO_UTC_CLOCK
    result.wall = TimeValue(Duration(result.wall) + duration)
#endif

    return result
  }

  public func duration(to other: Test.Clock.Instant) -> Duration {
    Duration(other.suspending) - Duration(suspending)
  }
}

// MARK: - Duration descriptions

extension Test.Clock.Instant {
  /// Get a description of the duration between this instance and another.
  ///
  /// - Parameters:
  ///   - other: The later instant.
  ///
  /// - Returns: A string describing the duration between `self` and `other`,
  ///   up to millisecond accuracy.
  func descriptionOfDuration(to other: Test.Clock.Instant) -> String {
#if SWT_TARGET_OS_APPLE
    let (seconds, nanosecondsRemaining) = nanoseconds(until: other).quotientAndRemainder(dividingBy: 1_000_000_000)
    return String(describing: TimeValue((seconds, nanosecondsRemaining * 1_000_000_000)))
#else
    return String(describing: TimeValue(Duration(other.suspending) - Duration(suspending)))
#endif
  }
}

// MARK: - Codable

extension Test.Clock.Instant: Codable {}
