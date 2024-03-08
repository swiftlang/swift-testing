//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that defines a time limit to apply to a test.
///
/// To add this trait to a test, use one of the following functions:
///
/// - ``Trait/timeLimit(_:)``
@available(_clockAPI, *)
public struct TimeLimitTrait: TestTrait, SuiteTrait {
  /// The maximum amount of time a test may run for before timing out.
  public var timeLimit: Duration

  public var isRecursive: Bool {
    // Since test functions cannot be nested inside other test functions,
    // inheriting time limits from a parent test implies inheriting them from
    // parent test suite types. Types do not take any time to execute on their
    // own (other than some testing library overhead.)
    true
  }
}

// MARK: -

@available(_clockAPI, *)
extension Trait where Self == TimeLimitTrait {
  /// Construct a time limit trait that causes a test to time out if it runs for
  /// too long.
  ///
  /// - Parameters:
  ///   - timeLimit: The maximum amount of time the test may run for.
  ///
  /// - Returns: An instance of ``TimeLimitTrait``.
  ///
  /// When this trait is associated with a test, that test must complete within
  /// a time limit of, at most, `timeLimit`. If the test runs longer, an issue
  /// of kind ``Issue/Kind/timeLimitExceeded(timeLimitComponents:)`` is
  /// recorded. This timeout is treated as a test failure.
  ///
  /// If a test is parameterized, this time limit is applied to each of its
  /// test cases individually. If a test has more than one time limit associated
  /// with it, the shortest one is used. A test run may also be configured with
  /// a maximum time limit per test case.
  public static func timeLimit(_ timeLimit: Duration) -> Self {
    return Self(timeLimit: timeLimit)
  }
}

// MARK: -

@available(_clockAPI, *)
extension Test {
  /// The maximum amount of time the cases of this test may run for.
  ///
  /// Time limits are associated with tests using this trait:
  ///
  /// - ``Trait/timeLimit(_:)``
  ///
  /// If a test has more than one time limit associated with it, the value of
  /// this property is the shortest one. If a test has no time limits associated
  /// with it, the value of this property is `nil`.
  public var timeLimit: Duration? {
    traits.lazy
      .compactMap { $0 as? TimeLimitTrait }
      .map(\.timeLimit)
      .min()
  }

  /// Get the maximum amount of time the cases of this test may run for, taking
  /// the current configuration and any library-imposed rules into account.
  ///
  /// - Parameters:
  ///   - configuration: The current configuration.
  ///
  /// - Returns: The maximum amount of time the cases of this test may run for,
  ///   or `nil` if the test may run indefinitely.
  @_spi(ForToolsIntegrationOnly)
  public func adjustedTimeLimit(configuration: Configuration) -> Duration? {
    // If this instance doesn't have a time limit configured, use the default
    // specified by the configuration.
    var timeLimit = timeLimit ?? configuration.defaultTestTimeLimit

    // Round the time limit.
    timeLimit = timeLimit.map { timeLimit in
      let granularity = configuration.testTimeLimitGranularity
      return granularity * (timeLimit / granularity).rounded(.awayFromZero)
    }

    // Do not exceed the maximum time limit specified by the configuration.
    // Perform this step after rounding to avoid exceeding the maximum (which
    // could occur if it is not a multiple of the granularity value.)
    if let maximumTestTimeLimit = configuration.maximumTestTimeLimit {
      timeLimit = timeLimit.map { timeLimit in
        min(timeLimit, maximumTestTimeLimit)
      } ?? maximumTestTimeLimit
    }

    return timeLimit
  }
}

// MARK: -

#if !SWT_NO_UNSTRUCTURED_TASKS
/// Invoke a function with a timeout.
///
/// - Parameters:
///   - timeLimit: The amount of time until the closure times out.
///   - body: The function to invoke.
///   - timeoutHandler: A function to invoke if `body` times out.
///
/// - Throws: Any error thrown by `body`.
///
/// If `body` does not return or throw before `timeLimit` is reached,
/// `timeoutHandler` is called and given the opportunity to handle the timeout
/// and `body` is cancelled.
///
/// This function is not part of the public interface of the testing library.
@available(_clockAPI, *)
func withTimeLimit(
  _ timeLimit: Duration,
  _ body: @escaping @Sendable () async throws -> Void,
  timeoutHandler: @escaping @Sendable () -> Void
) async throws {
  try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask {
      // If sleep() returns instead of throwing a CancellationError, that means
      // the timeout was reached before this task could be cancelled, so call
      // the timeout handler.
      try await Test.Clock.sleep(for: timeLimit)
      timeoutHandler()
    }
    group.addTask(operation: body)

    defer {
      group.cancelAll()
    }
    try await group.next()!
  }
}
#endif

/// Invoke a closure with a time limit derived from an instance of ``Test``.
///
/// - Parameters:
///   - test: The test that may time out.
///   - configuration: The current configuration.
///   - body: The function to invoke.
///   - timeoutHandler: A function to invoke if `body` times out. The time limit
///     applied to `body` is passed to this function.
///
/// - Throws: Any error thrown by `body`.
///
/// This function is provided as a cross-platform convenience wrapper around
/// ``withTimeLimit(_:_:timeoutHandler:)``. If the current platform does not
/// support time limits or the Swift clock API, this function invokes `body`
/// with no time limit.
///
/// This function is not part of the public interface of the testing library.
func withTimeLimit(
  for test: Test,
  configuration: Configuration,
  _ body: @escaping @Sendable () async throws -> Void,
  timeoutHandler: @escaping @Sendable (_ timeLimit: (seconds: Int64, attoseconds: Int64)) -> Void
) async throws {
  if #available(_clockAPI, *),
     let timeLimit = test.adjustedTimeLimit(configuration: configuration) {
#if SWT_NO_UNSTRUCTURED_TASKS
    // This environment may not support full concurrency, so check if the body
    // closure timed out after it returns. This won't help us catch hangs, but
    // it will at least report tests that run longer than expected.
    let start = Test.Clock.Instant.now
    defer {
      if start.duration(to: .now) > timeLimit {
        timeoutHandler(timeLimit.components)
      }
    }
    try await body()
#else
    return try await withTimeLimit(timeLimit) {
      try await body()
    } timeoutHandler: {
      timeoutHandler(timeLimit.components)
    }
#endif
  }

  try await body()
}
