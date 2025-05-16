//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// Poll an expression to check that it passes until the given duration
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
///
/// This function contains the implementation for `#expect(until:)` when no
/// error is expected and no value should be returned.
@available(macOS 13, iOS 17, watchOS 9, tvOS 17, visionOS 1, *)
func callPolling(
  behavior: PollingBehavior,
  timeout: Duration,
  closure: @escaping @Sendable () async throws -> Bool,
  expression: __Expression,
  comments: [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) async -> Result<Void, any Error>{
  await Polling.run(
    behavior: behavior,
    timeout: timeout,
    closure: {
      do {
        return try await closure()
      } catch {
        return false
      }
    },
    expression: expression,
    comments: comments,
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

/// Poll an expression to check that it passes until the given duration
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
///
/// This function contains the implementation for `#expect(until:)` when an
/// equatable error is expected and no value should be returned.
@available(macOS 13, iOS 17, watchOS 9, tvOS 17, visionOS 1, *)
func callPolling<E>(
  behavior: PollingBehavior,
  throws error: E,
  timeout: Duration,
  closure: @escaping @Sendable () async throws -> Bool,
  expression: __Expression,
  comments: [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) async -> Result<Void, any Error> where E: Error & Equatable {
  await Polling.run(
    behavior: behavior,
    timeout: timeout,
    closure: {
      do {
        _ = try await closure()
        return false
      } catch let thrownError as E {
        return thrownError == error
      } catch {
        return false
      }
    },
    expression: expression,
    comments: comments,
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

/// Poll an expression to check that it passes until the given duration
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
///
/// This function contains the implementation for `#expect(until:)` when an
/// error is expected and no value should be returned.
@available(macOS 13, iOS 17, watchOS 9, tvOS 17, visionOS 1, *)
func callPolling(
  behavior: PollingBehavior,
  timeout: Duration,
  closure: @escaping @Sendable () async throws -> Bool,
  errorMatcher: @escaping @Sendable (any Error) async throws -> Bool,
  expression: __Expression,
  comments: [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) async -> Result<Void, any Error> {
  await Polling.run(
    behavior: behavior,
    timeout: timeout,
    closure: {
      do {
        _ = try await closure()
        return false
      } catch {
        return (try? await errorMatcher(error)) == true
      }
    },
    expression: expression,
    comments: comments,
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

/// Poll an expression to check that it passes until the given duration
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
///
/// This function contains the implementation for `#require(until:)` when no
/// error is expected and a value should be returned.
@available(macOS 13, iOS 17, watchOS 9, tvOS 17, visionOS 1, *)
func callPolling<R>(
  behavior: PollingBehavior,
  timeout: Duration,
  closure: @escaping @Sendable () async throws -> R?,
  errorMatcher: @escaping @Sendable (any Error) async throws -> Bool,
  expression: __Expression,
  comments: [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) async -> Result<R, any Error> where R: Sendable {
  await Polling.run(
    behavior: behavior,
    timeout: timeout,
    closure: {
      do {
        return try await closure()
      } catch {
        return nil
      }
    },
    expression: expression,
    comments: comments,
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}
