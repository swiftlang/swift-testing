//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// Default values for polling confirmations.
@available(_clockAPI, *)
internal let defaultPollingConfiguration = (
  pollingDuration: Duration.seconds(1),
  pollingInterval: Duration.milliseconds(1)
)

/// A type describing an error thrown when polling fails.
@_spi(Experimental)
public struct PollingFailedError: Error, Sendable, Codable {
  /// A user-specified comment describing this confirmation
  public var comment: Comment?

  /// A ``SourceContext`` indicating where and how this confirmation was called
  @_spi(ForToolsIntegrationOnly)
  public var sourceContext: SourceContext

  /// Initialize an instance of this type with the specified details
  ///
  /// - Parameters:
  ///   - comment: A user-specified comment describing this confirmation.
  ///     Defaults to `nil`.
  ///   - sourceContext: A ``SourceContext`` indicating where and how this
  ///     confirmation was called.
  public init(
    comment: Comment? = nil,
    sourceContext: SourceContext
  ) {
    self.comment = comment
    self.sourceContext = sourceContext
  }
}

extension PollingFailedError: CustomIssueRepresentable {
  func customize(_ issue: consuming Issue) -> Issue {
    if let comment {
      issue.comments.append(comment)
    }
    issue.kind = .pollingConfirmationFailed
    issue.sourceContext = sourceContext
    return issue
  }
}

/// A type defining when to stop polling early.
/// This also determines what happens if the duration elapses during polling.
public enum PollingStopCondition: Sendable, Equatable {
  /// Evaluates the expression until the first time it returns true.
  /// If it does not pass once by the time the timeout is reached, then a
  /// failure will be reported.
  case firstPass

  /// Evaluates the expression until the first time it returns false.
  /// If the expression returns false, then a failure will be reported.
  /// If the expression only returns true before the timeout is reached, then
  /// no failure will be reported.
  /// If the expression does not finish evaluating before the timeout is
  /// reached, then a failure will be reported.
  case stopsPassing
}

/// Poll expression within the duration based on the given stop condition
///
/// - Parameters:
///   - comment: A user-specified comment describing this confirmation.
///   - stopCondition: When to stop polling.
///   - duration: The expected length of time to continue polling for.
///     This value may not correspond to the wall-clock time that polling lasts
///     for, especially on highly-loaded systems with a lot of tests running.
///     If nil, this uses whatever value is specified under the last
///     ``PollingConfirmationConfigurationTrait`` added to the test or suite
///     with a matching stopCondition.
///     If no such trait has been added, then polling will be attempted for
///     about 1 second before recording an issue.
///     `duration` must be greater than 0.
///   - interval: The minimum amount of time to wait between polling attempts.
///     If nil, this uses whatever value is specified under the last
///     ``PollingConfirmationConfigurationTrait`` added to the test or suite
///     with a matching stopCondition.
///     If no such trait has been added, then polling will wait at least
///     1 millisecond between polling attempts.
///     `interval` must be greater than 0.
///   - isolation: The actor to which `body` is isolated, if any.
///   - sourceLocation: The location in source where the confirmation was called.
///   - body: The function to invoke.
///
/// - Throws: A `PollingFailedError` if the `body` does not return true within
///   the polling duration.
///
/// Use polling confirmations to check that an event while a test is running in
/// complex scenarios where other forms of confirmation are insufficient. For
/// example, waiting on some state to change that cannot be easily confirmed
/// through other forms of `confirmation`.
@_spi(Experimental)
@available(_clockAPI, *)
public func confirmation(
  _ comment: Comment? = nil,
  until stopCondition: PollingStopCondition,
  within duration: Duration? = nil,
  pollingEvery interval: Duration? = nil,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation = #_sourceLocation,
  _ body: @escaping () async throws -> Bool
) async throws {
  let poller = Poller(
    stopCondition: stopCondition,
    duration: stopCondition.duration(with: duration),
    interval: stopCondition.interval(with: interval),
    comment: comment,
    sourceContext: SourceContext(
      backtrace: .current(),
      sourceLocation: sourceLocation
    )
  )
  try await poller.evaluate(isolation: isolation) {
    do {
      return try await body()
    } catch {
      return false
    }
  }
}

/// Confirm that some expression eventually returns a non-nil value
///
/// - Parameters:
///   - comment: A user-specified comment describing this confirmation.
///   - stopCondition: When to stop polling.
///   - duration: The expected length of time to continue polling for.
///     This value may not correspond to the wall-clock time that polling lasts
///     for, especially on highly-loaded systems with a lot of tests running.
///     If nil, this uses whatever value is specified under the last
///     ``PollingConfirmationConfigurationTrait`` added to the test or suite
///     with a matching stopCondition.
///     If no such trait has been added, then polling will be attempted for
///     about 1 second before recording an issue.
///     `duration` must be greater than 0.
///   - interval: The minimum amount of time to wait between polling attempts.
///     If nil, this uses whatever value is specified under the last
///     ``PollingConfirmationConfigurationTrait`` added to the test or suite
///     with a matching stopCondition.
///     If no such trait has been added, then polling will wait at least
///     1 millisecond between polling attempts.
///     `interval` must be greater than 0.
///   - isolation: The actor to which `body` is isolated, if any.
///   - sourceLocation: The location in source where the confirmation was called.
///   - body: The function to invoke.
///
/// - Throws: A `PollingFailedError` if the `body` does not return true within
///   the polling duration.
///
/// - Returns: The last non-nil value returned by `body`.
///
/// Use polling confirmations to check that an event while a test is running in
/// complex scenarios where other forms of confirmation are insufficient. For
/// example, waiting on some state to change that cannot be easily confirmed
/// through other forms of `confirmation`.
@_spi(Experimental)
@available(_clockAPI, *)
@discardableResult
public func confirmation<R>(
  _ comment: Comment? = nil,
  until stopCondition: PollingStopCondition,
  within duration: Duration? = nil,
  pollingEvery interval: Duration? = nil,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation = #_sourceLocation,
  _ body: @escaping () async throws -> sending R?
) async throws -> R {
  let poller = Poller(
    stopCondition: stopCondition,
    duration: stopCondition.duration(with: duration),
    interval: stopCondition.interval(with: interval),
    comment: comment,
    sourceContext: SourceContext(
      backtrace: .current(),
      sourceLocation: sourceLocation
    )
  )
  return try await poller.evaluateOptional(isolation: isolation) {
    do {
      return try await body()
    } catch {
      return nil
    }
  }
}

/// A helper function to de-duplicate the logic of grabbing configuration from
/// either the passed-in value (if given), the hardcoded default, and the
/// appropriate configuration trait.
///
/// The provided value, if non-nil is returned. Otherwise, this looks for
/// the last `TraitKind` specified, and if one exists, returns the value
/// as determined by `keyPath`.
/// If the provided value is nil, and no configuration trait has been applied,
/// then this returns the value specified in `default`.
///
/// - Parameters:
///   - providedValue: The value provided by the test author when calling
///     `confirmPassesEventually` or `confirmAlwaysPasses`.
///   - default: The harded coded default value, as defined in
///     `defaultPollingConfiguration`.
///   - keyPath: The keyPath mapping from `TraitKind` to the value type.
///
/// - Returns: The value to use.
private func getValueFromTrait<TraitKind, Value>(
  providedValue: Value?,
  default: Value,
  _ keyPath: KeyPath<TraitKind, Value?>,
  where filter: @escaping (TraitKind) -> Bool
) -> Value {
  if let providedValue { return providedValue }
  guard let test = Test.current else { return `default` }
  let possibleTraits = test.traits.compactMap { $0 as? TraitKind }
    .filter(filter)
  let traitValues = possibleTraits.compactMap { $0[keyPath: keyPath] }
  return traitValues.last ?? `default`
}

extension PollingStopCondition {
  /// Process the result of a polled expression and decide whether to continue
  /// polling.
  ///
  /// - Parameters:
  ///   - expressionResult: The result of the polled expression.
  ///
  /// - Returns: A poll result (if polling should stop), or nil (if polling
  ///   should continue).
  @available(_clockAPI, *)
  fileprivate func shouldStopPolling(
    expressionResult result: Bool
  ) -> Bool {
    switch self {
    case .firstPass:
      return result
    case .stopsPassing:
      return !result
    }
  }

  /// Determine the polling duration to use for the given provided value.
  /// Based on ``getValueFromTrait``, this falls back using
  /// ``defaultPollingConfiguration.pollingInterval`` and
  /// ``PollingUntilFirstPassConfigurationTrait``.
  @available(_clockAPI, *)
  fileprivate func duration(with provided: Duration?) -> Duration {
    getValueFromTrait(
      providedValue: provided,
      default: defaultPollingConfiguration.pollingDuration,
      \PollingConfirmationConfigurationTrait.duration,
      where: { $0.stopCondition == self }
    )
  }

  /// Determine the polling interval to use for the given provided value.
  /// Based on ``getValueFromTrait``, this falls back using
  /// ``defaultPollingConfiguration.pollingInterval`` and
  /// ``PollingUntilFirstPassConfigurationTrait``.
  @available(_clockAPI, *)
  fileprivate func interval(with provided: Duration?) -> Duration {
    getValueFromTrait(
      providedValue: provided,
      default: defaultPollingConfiguration.pollingInterval,
      \PollingConfirmationConfigurationTrait.interval,
      where: { $0.stopCondition == self }
    )
  }
}

/// A type for managing polling
@available(_clockAPI, *)
private struct Poller {
  /// The stop condition to follow
  let stopCondition: PollingStopCondition

  /// Approximately how long to poll for
  let duration: Duration

  /// The minimum waiting period between polling
  let interval: Duration

  /// A user-specified comment describing this confirmation
  let comment: Comment?

  /// A ``SourceContext`` indicating where and how this confirmation was called
  let sourceContext: SourceContext

  /// Evaluate polling, throwing an error if polling fails.
  ///
  /// - Parameters:
  ///   - isolation: The isolation to use.
  ///   - body: The expression to poll.
  ///
  /// - Throws: A ``PollingFailedError`` if polling doesn't pass.
  ///
  /// - Returns: Whether or not polling passed.
  ///
  /// - Side effects: If polling fails (see ``PollingStopCondition``), then
  ///   this will record an issue.
  @discardableResult func evaluate(
    isolation: isolated (any Actor)?,
    _ body: @escaping () async -> Bool
  ) async throws -> Bool {
    try await evaluateOptional(isolation: isolation) {
      if await body() {
        // return any non-nil value.
        return true
      } else {
        return nil
      }
    } != nil
  }

  /// Evaluate polling, throwing an error if polling fails.
  ///
  /// - Parameters:
  ///   - isolation: The isolation to use.
  ///   - body: The expression to poll.
  ///
  /// - Throws: A ``PollingFailedError`` if polling doesn't pass.
  ///
  /// - Returns: the last non-nil value returned by `body`.
  ///
  /// - Side effects: If polling fails (see ``PollingStopCondition``), then
  ///   this will record an issue.
  @discardableResult func evaluateOptional<R>(
    isolation: isolated (any Actor)?,
    _ body: @escaping () async -> sending R?
  ) async throws -> R {
    precondition(duration > Duration.zero)
    precondition(interval > Duration.zero)
    precondition(duration > interval)

    let iterations = max(Int(duration.seconds() / interval.seconds()), 1)

    if let value = await poll(iterations: iterations, expression: body) {
      return value
    } else {
      throw PollingFailedError(comment: comment, sourceContext: sourceContext)
    }
  }

  /// This function contains the logic for continuously polling an expression,
  /// as well as processing the results of that expression.
  ///
  /// - Parameters:
  ///   - iterations: The maximum amount of times to continue polling.
  ///   - expression: An expression to continuously evaluate.
  ///
  /// - Returns: The most recent value if the polling succeeded, else nil.
  private func poll<R>(
    iterations: Int,
    isolation: isolated (any Actor)? = #isolation,
    expression: @escaping () async -> sending R?
  ) async -> R? {
    var lastResult: R?
    for iteration in 0..<iterations {
      lastResult = await expression()
      if stopCondition.shouldStopPolling(expressionResult: lastResult != nil) {
        return lastResult
      }
      if iteration == (iterations - 1) {
        // don't bother sleeping if it's the last iteration.
        break
      }
      do {
        try await Task.sleep(for: interval)
      } catch {
        // `Task.sleep` should only throw an error if it's cancelled
        // during the sleep period.
        return nil
      }
    }
    return lastResult
  }
}

@available(_clockAPI, *)
private extension Duration {
  /// The duration, as a ``Double``.
  func seconds() -> Double {
    let secondsComponent = Double(components.seconds)
    let attosecondsComponent = Double(components.attoseconds) * 1e-18
    return secondsComponent + attosecondsComponent
  }
}
