//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type for managing polling
@available(macOS 13, iOS 17, watchOS 9, tvOS 17, visionOS 1, *)
struct Polling {
  /// Run polling for a closure that evaluates to a boolean value.
  ///
  /// - Parameters:
  ///   - behavior: The PollingBehavior to use.
  ///   - timeout: How long to poll for until we time out.
  ///   - closure: The closure to continuously evaluate.
  ///   - expression: The expression, corresponding to `condition`, that is being
  ///     evaluated (if available at compile time.)
  ///   - comments: An array of comments describing the expectation. This array
  ///     may be empty.
  ///   - isRequired: Whether or not the expectation is required. The value of
  ///     this argument does not affect whether or not an error is thrown on
  ///     failure.
  ///   - sourceLocation: The source location of the expectation.
  static func run(
    behavior: PollingBehavior,
    timeout: Duration,
    closure: @escaping @Sendable () async -> Bool,
    expression: __Expression,
    comments: [Comment],
    isRequired: Bool,
    sourceLocation: SourceLocation
  ) async -> Result<Void, any Error> {
    var expectation = Expectation(
      evaluatedExpression: expression,
      isPassing: true,
      isRequired: isRequired,
      sourceLocation: sourceLocation
    )

    let result = await poll(expression: closure, behavior: behavior, timeout: timeout)

    let sourceContext = SourceContext(backtrace: nil, sourceLocation: sourceLocation)

    switch result {
    case .timedOut:
      expectation.isPassing = false
      Issue(
        kind: .expectationFailed(expectation),
        comments: comments,
        sourceContext: sourceContext
      ).record()
    case .timedOutWithoutRunning:
      expectation.isPassing = false
      Issue(
        kind: .expectationFailed(expectation),
        comments: comments,
        sourceContext: sourceContext
      ).record()
    case .finished:
      return __checkValue(
        true,
        expression: expression,
        comments: comments,
        isRequired: isRequired,
        sourceLocation: sourceLocation
      )
    case .failed:
      return __checkValue(
        false,
        expression: expression,
        comments: comments,
        isRequired: isRequired,
        sourceLocation: sourceLocation
      )
    case .cancelled:
      Issue(
        kind: .system,
        comments: comments,
        sourceContext: sourceContext
      ).record()
    }

    return .failure(ExpectationFailedError(expectation: expectation))
  }

  /// Run polling for a closure that evaluates to an optional value.
  ///
  /// - Parameters:
  ///   - behavior: The PollingBehavior to use.
  ///   - timeout: How long to poll for until we time out.
  ///   - closure: The closure to continuously evaluate.
  ///   - expression: The expression, corresponding to `condition`, that is being
  ///     evaluated (if available at compile time.)
  ///   - comments: An array of comments describing the expectation. This array
  ///     may be empty.
  ///   - isRequired: Whether or not the expectation is required. The value of
  ///     this argument does not affect whether or not an error is thrown on
  ///     failure.
  ///   - sourceLocation: The source location of the expectation.
  static func run<R>(
    behavior: PollingBehavior,
    timeout: Duration,
    closure: @escaping @Sendable () async -> R?,
    expression: __Expression,
    comments: [Comment],
    isRequired: Bool,
    sourceLocation: SourceLocation
  ) async -> Result<R, any Error> where R: Sendable {
    var expectation = Expectation(
      evaluatedExpression: expression,
      isPassing: true,
      isRequired: isRequired,
      sourceLocation: sourceLocation
    )

    let recorder = Recorder<R>()

    let result = await poll(expression: {
      if let value = await closure() {
        await recorder.record(value: value)
        return true
      }
      return false
    }, behavior: behavior, timeout: timeout)

    let sourceContext = SourceContext(backtrace: nil, sourceLocation: sourceLocation)

    switch result {
    case .timedOut:
      expectation.isPassing = false
      Issue(
        kind: .expectationFailed(expectation),
        comments: comments,
        sourceContext: sourceContext
      ).record()
    case .timedOutWithoutRunning:
      expectation.isPassing = false
      Issue(
        kind: .expectationFailed(expectation),
        comments: comments,
        sourceContext: sourceContext
      ).record()
    case .finished:
      return __checkValue(
        await recorder.lastValue,
        expression: expression,
        comments: comments,
        isRequired: isRequired,
        sourceLocation: sourceLocation
      )
    case .failed:
      return __checkValue(
        nil,
        expression: expression,
        comments: comments,
        isRequired: isRequired,
        sourceLocation: sourceLocation
      )
    case .cancelled:
      Issue(
        kind: .system,
        comments: comments,
        sourceContext: sourceContext
      ).record()
    }

    return .failure(ExpectationFailedError(expectation: expectation))
  }

  /// A type to record the last value returned by a closure returning an optional
  /// This is only used in the `#require(until:)` macro returning an optional.
  private actor Recorder<R: Sendable> {
    var lastValue: R?

    /// Record a new value to be returned
    func record(value: R) {
      self.lastValue = value
    }
  }

  /// The result of polling expressions
  private enum PollResult {
    /// The polling timed out, and the expression had run at least once.
    case timedOut
    /// The polling timed out, but the expression had not finished running in
    /// that time.
    case timedOutWithoutRunning
    /// The expression exited early, and we will report a success status.
    case finished
    /// The expression returned false under PollingBehavior.passesAlways
    case failed
    /// The polling was cancelled before polling could finish
    case cancelled
  }

  /// The poll manager.
  ///
  /// This function contains the logic for continuously polling an expression,
  /// as well as the logic for cancelling the polling once it times out.
  ///
  /// - Parameters:
  ///   - expression: An expression to continuously evaluate
  ///   - behavior: The polling behavior to use
  ///   - timeout: How long to poll for unitl the timeout triggers.
  /// - Returns: The result of this polling.
  private static func poll(
    expression: @escaping @Sendable () async -> Bool,
    behavior: PollingBehavior,
    timeout: Duration
  ) async -> PollResult {
    let pollingProcessor = PollingProcessor(behavior: behavior)
    return await withTaskGroup { taskGroup in
      taskGroup.addTask {
        do {
          try await Task.sleep(for: timeout)
        } catch {}
        // Task.sleep will only throw if it's cancelled, at which point this
        // taskgroup has already returned and we don't care about the value
        // returned here.
        return await pollingProcessor.didTimeout()
      }
      taskGroup.addTask {
        while Task.isCancelled == false {
          let expressionPassed = await expression()
          if let result = await pollingProcessor.expressionFinished(result: expressionPassed) {
            return result
          }
        }
        // The expression was cancelled without having been finished.
        // This should end up being reported as a timeout error, due to
        // the earlier task added to this task group.
        // But there's a chance that the overall task was cancelled.
        // in which case, we should report that as a system error.
        return PollResult.cancelled
      }

      defer { taskGroup.cancelAll() }
      return await taskGroup.next() ?? .timedOut
    }
  }

  /// A type to process events from `Polling.poll`.
  private actor PollingProcessor {
    let behavior: PollingBehavior
    var hasRun = false

    init(behavior: PollingBehavior) {
      self.behavior = behavior
    }

    /// Record a timeout event from polling.
    func didTimeout() -> PollResult {
      if !hasRun {
        return PollResult.timedOutWithoutRunning
      }
      switch behavior {
      case .passesOnce:
        return PollResult.timedOut
      case .passesAlways:
        return PollResult.finished
      }
    }

    /// Record that an expression finished running
    ///
    /// - Parameters:
    ///   - Result: Whether or not the polled expression passed or not.
    ///
    /// - Returns: A non-nil PollResult if polling should exit, otherwise nil.
    func expressionFinished(result: Bool) -> PollResult? {
      hasRun = true

      switch behavior {
      case .passesOnce:
        if result {
          return .finished
        } else {
          return nil
        }
      case .passesAlways:
        if !result {
          return .failed
        } else {
          return nil
        }
      }
    }
  }
}
