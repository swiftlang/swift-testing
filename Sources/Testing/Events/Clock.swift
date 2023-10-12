//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_implementationOnly import TestingInternals

@_spi(ExperimentalEventHandling)
extension Test {
  /// A clock used to track time when events occur during testing.
  ///
  /// This clock tracks time using both the [suspending clock](https://developer.apple.com/documentation/swift/suspendingclock)
  /// and the wall clock. Only the suspending clock is used for comparing and
  /// calculating; the wall clock is used for presentation when needed.
  public struct Clock: Sendable {
    /// An instant on the testing clock.
    public struct Instant: Sendable {
#if SWT_TARGET_OS_APPLE
      /// The number of nanoseconds that have passed since the system started.
      ///
      /// The testing library's availability on Apple platforms is earlier than
      /// that of the Swift Clock API, so we don't use SuspendingClock directly
      /// on them.
      fileprivate(set) var uptime: timespec = {
        // SuspendingClock corresponds to CLOCK_UPTIME_RAW on Darwin.
        // SEE: https://github.com/apple/swift/blob/main/stdlib/public/Concurrency/Clock.cpp
        var uptime = timespec()
        _ = clock_gettime(CLOCK_UPTIME_RAW, &uptime)
        return uptime
      }()
#else
      /// The corresponding suspending-clock time.
      fileprivate var suspending = SuspendingClock.Instant.now
#endif

#if !SWT_NO_UTC_CLOCK
      /// The corresponding wall-clock time, in seconds and nanoseconds.
      ///
      /// This value is stored as an instance of `timespec` rather than an
      /// instance of `Duration` because the latter type requires that the Swift
      /// clocks API be available.
      fileprivate var wall: timespec = {
        var wall = timespec()
        timespec_get(&wall, TIME_UTC)
        return wall
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

// MARK: - Converting to other clocks

extension timespec {
  /// Initialize an instance of this type from an instance of `Duration`.
  ///
  /// - Parameters:
  ///   - duration: The duration to initialize this instance from.
  ///
  /// The standard library includes an initializer of this form, but it is not
  /// available on all platforms.
  ///
  /// This initializer is not part of the public interface of the testing
  /// library.
  @available(_clockAPI, *)
  init(_ duration: Duration) {
    self.init(duration.components)
  }

  /// Initialize an instance of this type from a tuple containing seconds and
  /// attoseconds values.
  ///
  /// - Parameters:
  ///   - components: A tuple containing the seconds and attoseconds values to
  ///     initialize this instance from. The `attoseconds` element is truncated
  ///     to nanoseconds.
  ///
  /// This initializer is not part of the public interface of the testing
  /// library.
  init(_ components: (seconds: Int64, attoseconds: Int64)) {
    self.init(
      tv_sec: .init(components.seconds),
      tv_nsec: .init(components.attoseconds / 1_000_000_000)
    )
  }

  /// The number of nanoseconds represented by this instance.
  ///
  /// This property is not part of the public interface of the testing library.
  var nanoseconds: Int64 {
    (Int64(tv_sec) * 1_000_000_000) + Int64(tv_nsec)
  }
}

@available(_clockAPI, *)
extension Duration {
  /// Initialize an instance of this type from an instance of `timespec`.
  ///
  /// - Parameters:
  ///   - ts: The `timespec` value to initialize this instance from.
  ///
  /// The standard library includes an initializer of this form, but it is not
  /// available on all platforms.
  ///
  /// This initializer is not part of the public interface of the testing
  /// library.
  init(_ ts: timespec) {
    self = .seconds(ts.tv_sec) + .nanoseconds(ts.tv_nsec)
  }
}

@_spi(ExperimentalEventHandling)
@available(_clockAPI, *)
extension SuspendingClock.Instant {
  /// Initialize this instant to the equivalent of the same instant on the
  /// testing library's clock.
  ///
  /// - Parameters:
  ///   - testClockInstant: The equivalent instant on ``Test/Clock``.
  public init(_ testClockInstant: Test.Clock.Instant) {
#if SWT_TARGET_OS_APPLE
    let duration = Duration(testClockInstant.uptime)
    self = unsafeBitCast(duration, to: Self.self)
#else
    self = testClockInstant.suspending
#endif
  }
}

#if !SWT_NO_UTC_CLOCK
@_spi(ExperimentalEventHandling)
extension Test.Clock.Instant {
  /// The number of nanoseconds since 1970 represented by this instance.
  ///
  /// The value of this property is the equivalent of `self` on the wall clock.
  /// It is suitable for display to the user, but not for fine timing
  /// calculations.
  public var nanosecondsSince1970: Int64 {
    wall.nanoseconds
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
}
#endif

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
    var ts = timespec(duration)
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

@_spi(ExperimentalEventHandling)
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
    return Duration(res)
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

@_spi(ExperimentalEventHandling)
extension Test.Clock.Instant: Equatable, Hashable, Comparable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
#if SWT_TARGET_OS_APPLE
    lhs.uptime.tv_sec == rhs.uptime.tv_sec && lhs.uptime.tv_nsec == rhs.uptime.tv_nsec
#else
    lhs.suspending == rhs.suspending
#endif
  }

  public func hash(into hasher: inout Hasher) {
#if SWT_TARGET_OS_APPLE
    hasher.combine(uptime.tv_sec)
    hasher.combine(uptime.tv_nsec)
#else
    hasher.combine(suspending)
#endif
  }

  public static func <(lhs: Self, rhs: Self) -> Bool {
#if SWT_TARGET_OS_APPLE
    if lhs.uptime.tv_sec != rhs.uptime.tv_sec {
      return lhs.uptime.tv_sec < rhs.uptime.tv_sec
    }
    return lhs.uptime.tv_nsec < rhs.uptime.tv_nsec
#else
    lhs.suspending < rhs.suspending
#endif
  }
}

// MARK: - InstantProtocol

@_spi(ExperimentalEventHandling)
@available(_clockAPI, *)
extension Test.Clock.Instant: InstantProtocol {
  public typealias Duration = Swift.Duration

  public func advanced(by duration: Duration) -> Self {
    var result = self

#if SWT_TARGET_OS_APPLE
    result.uptime = timespec(Duration(uptime) + duration)
#else
    result.suspending = suspending.advanced(by: duration)
#endif
#if !SWT_NO_UTC_CLOCK
    result.wall = timespec(result.durationSince1970 + duration)
#endif

    return result
  }

  public func duration(to other: Test.Clock.Instant) -> Duration {
#if SWT_TARGET_OS_APPLE
    Duration(other.uptime) - Duration(uptime)
#else
    suspending.duration(to: other.suspending)
#endif
  }
}

// MARK: - Duration descriptions

/// Get a description of a duration in nanoseconds.
///
/// - Parameters:
///   - nanoseconds: The duration, in nanoseconds.
///
/// - Returns: A string describing the specified duration.
private func _descriptionOfNanoseconds(_ nanoseconds: Int64) -> String {
  let (seconds, nanosecondsRemaining) = nanoseconds.quotientAndRemainder(dividingBy: 1_000_000_000)
  var milliseconds = nanosecondsRemaining / 1_000_000
  if seconds == 0 && milliseconds == 0 && nanosecondsRemaining > 0 {
    milliseconds = 1
  }

  return withUnsafeTemporaryAllocation(of: CChar.self, capacity: 512) { buffer in
    withVaList([CLongLong(seconds), CInt(milliseconds)]) { args in
      _ = vsnprintf(buffer.baseAddress!, buffer.count, "%lld.%03d seconds", args)
    }
    return String(cString: buffer.baseAddress!)
  }
}

/// Get a description of a duration represented as a tuple containing seconds
/// and attoseconds.
///
/// - Parameters:
///   - components: The duration.
///
/// - Returns: A string describing the specified duration, up to millisecond
///   accuracy.
func descriptionOfTimeComponents(_ components: (seconds: Int64, attoseconds: Int64)) -> String {
  _descriptionOfNanoseconds(timespec(components).nanoseconds)
}

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
    _descriptionOfNanoseconds(other.uptime.nanoseconds - uptime.nanoseconds)
#else
    descriptionOfTimeComponents(suspending.duration(to: other.suspending).components)
#endif
  }
}

@available(_clockAPI, *)
extension Test.Clock.Instant: Codable {
  private enum CodingKeys: CodingKey {
    case suspending
    case wall
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
#if SWT_TARGET_OS_APPLE
    let suspending = SuspendingClock.Instant(self)
#endif
    try container.encode(suspending, forKey: .suspending)

#if !SWT_NO_UTC_CLOCK
    try container.encode(Duration(wall), forKey: .wall)
#endif
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let suspending = try container.decode(SuspendingClock.Instant.self, forKey: .suspending)
#if SWT_TARGET_OS_APPLE
    uptime = timespec(unsafeBitCast(suspending, to: Duration.self))
#else
    self.suspending = suspending
#endif

#if !SWT_NO_UTC_CLOCK
    // Only decode it if present - if it wasn't encoded we fall back to the
    // current wall clock time (via its default value).
    if let wall = try container.decodeIfPresent(Duration.self, forKey: .wall) {
      self.wall = timespec(wall)
    }
#endif
  }
}
