//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A type that sets environment variables for the duration of a test or
/// suite.
///
/// When you apply an instance of this trait to a test suite, the testing
/// library recursively applies it to all test suites and test functions within
/// it.
///
/// To add this trait to a test, use ``Trait/environment(_:)-80yv4``,
/// ``Trait/environment(_:)-8j89x``, or ``Trait/environment(_:_:)``.
///
/// @Metadata {
///   @Available(Swift, introduced: 6.5)
/// }
public struct EnvironmentTrait: SuiteTrait, TestTrait, Sendable {
  /// A dictionary containing the environment variables to set or unset.
  ///
  /// A value of `nil` indicates that the environment variable should be unset
  /// for the duration of the test.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public var variables: [String: String?]

  /// Constructs an instance of this trait with the specified variables.
  ///
  /// - Parameters:
  ///   - variables: A dictionary containing the environment variables and
  ///     their values to set. Pass `nil` as a value to unset the variable.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public init(variables: [String: String?]) {
    self.variables = variables
  }

  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public var isRecursive: Bool {
    true
  }
}

// MARK: - TestScoping

extension EnvironmentTrait: TestScoping {
  /// A serializer used to run environment-mutating tests in serial order,
  /// preventing data races in the process' environment block.
  private static let _environmentSerializer = Serializer<Void>()

  /// A task-local flag indicating whether the current task is already
  /// executing within an environment trait scope, allowing nested scopes
  /// without deadlocking on `_environmentSerializer`.
  @TaskLocal private static var _isInsideEnvironmentScope = false

  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: @Sendable () async throws -> Void
  ) async throws {
    if Self._isInsideEnvironmentScope {
      // Already within the serializer lock on this task tree; apply scoped overrides directly.
      try await _withEnvironmentOverrides(performing: function)
    } else {
      // Acquire the global environment serializer lock, then establish the scope.
      try await Self._environmentSerializer.run {
        try await Self.$_isInsideEnvironmentScope.withValue(true) {
          try await _withEnvironmentOverrides(performing: function)
        }
      }
    }
  }

  /// Apply the environment overrides, execute `function`, and restore the
  /// previous environment values in a `defer` block.
  private func _withEnvironmentOverrides(
    performing function: @Sendable () async throws -> Void
  ) async throws {
    var previousValues = [String: String?]()
    previousValues.reserveCapacity(variables.count)

    // Record current values so we can restore them later.
    for key in variables.keys {
      previousValues[key] = Environment.variable(named: key)
    }

    // Set the new values.
    for (key, value) in variables {
      Environment.setVariable(value, named: key)
    }

    defer {
      // Restore original environment values in reverse order of mutation.
      for (key, previousValue) in previousValues {
        Environment.setVariable(previousValue, named: key)
      }
    }

    try await function()
  }
}

#if !hasFeature(Embedded)
// MARK: - ReducibleTrait

@_spi(Experimental)
extension EnvironmentTrait: ReducibleTrait {
  public func reduce(into other: Self) -> Self? {
    // When multiple environment traits are applied (e.g. inherited from a suite
    // and overridden by a test function), merge them so that the innermost/latest
    // trait's keys take precedence over the outer trait's keys.
    var combined = other.variables
    for (key, value) in self.variables {
      combined[key] = value
    }
    return EnvironmentTrait(variables: combined)
  }
}
#endif

// MARK: -

extension Trait {
  /// Constructs a trait that sets environment variables for the duration of
  /// a test or suite.
  ///
  /// - Parameters:
  ///   - variables: A dictionary of environment variable names and their
  ///     desired values. Pass `nil` for a value to unset that variable.
  ///
  /// - Returns: An instance of ``EnvironmentTrait``.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public static func environment(
    _ variables: [String: String?]
  ) -> Self where Self == EnvironmentTrait {
    EnvironmentTrait(variables: variables)
  }

  /// Constructs a trait that sets environment variables for the duration of
  /// a test or suite.
  ///
  /// - Parameters:
  ///   - variables: A dictionary of environment variable names and their
  ///     desired string values.
  ///
  /// - Returns: An instance of ``EnvironmentTrait``.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public static func environment(
    _ variables: [String: String]
  ) -> Self where Self == EnvironmentTrait {
    EnvironmentTrait(variables: variables.mapValues { $0 as String? })
  }

  /// Constructs a trait that sets a single environment variable for the
  /// duration of a test or suite.
  ///
  /// - Parameters:
  ///   - name: The name of the environment variable.
  ///   - value: The value to set, or `nil` to unset the variable.
  ///
  /// - Returns: An instance of ``EnvironmentTrait``.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public static func environment(
    _ name: String,
    _ value: String?
  ) -> Self where Self == EnvironmentTrait {
    EnvironmentTrait(variables: [name: value])
  }
}
