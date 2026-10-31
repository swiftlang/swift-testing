//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that that binds a task local value for the duration of a test or
/// suite.
///
/// When you apply an instance of this trait to a test suite, the testing
/// library recursively applies it to all test suites and test functions within
/// it.
///
/// To add this trait to a test, use ``Trait/taskLocal(_:withValue:)``.
///
/// @Metadata {
///   @Available(Swift, introduced: 6.5)
/// }
public struct TaskLocalTrait<Value>: SuiteTrait, TestTrait where Value: Sendable {
  /// This trait's task-local value key.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public var taskLocal: TaskLocal<Value>

  /// A closure which returns a value this trait's task local will be bound to.
  private var _value: @Sendable () throws -> Value

  fileprivate init(taskLocal: TaskLocal<Value>, value: @escaping @Sendable () throws -> Value) {
    self.taskLocal = taskLocal
    self._value = value
  }

  /// Evaluate this trait's bound value.
  ///
  /// - Returns: The result of invoking the `value` closure passed to
  ///   ``Trait/taskLocal(_:withValue:)``.
  ///
  /// - Throws: Whatever is thrown when invoking the `value` closure passed to
  ///   ``Trait/taskLocal(_:withValue:)``.
  ///
  /// Each call to this function invokes the closure that was passed to
  /// ``Trait/taskLocal(_:withValue:)``. The resulting value isn't cached or
  /// stored by this trait, so repeated calls may produce different values or
  /// cause side effects to occur more than once.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public func evaluate() async throws -> Value {
    try _value()
  }

  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public var isRecursive: Bool {
    true
  }
}

// MARK: - TestScoping

extension TaskLocalTrait: TestScoping {
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: @Sendable () async throws -> Void
  ) async throws {
    try await taskLocal.withValue(evaluate()) {
      try await function()
    }
  }
}

// MARK: -

extension Trait {
  /// Constructs a trait that binds a task local value for the duration of a
  /// test or suite.
  ///
  /// - Parameters:
  ///   - taskLocal: The task local to bind the value to.
  ///   - value: The value to bind to `taskLocal`.
  ///
  ///     The testing library evaluates this value when the test this trait is
  ///     applied to runs. The value is bound to `taskLocal`, the test runs, and
  ///     then the value is unbound.
  ///
  /// - Note: You must define the task local outside the module where you use
  ///   this trait.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public static func taskLocal<Value>(
    _ taskLocal: TaskLocal<Value>,
    withValue value: @autoclosure @escaping @Sendable () throws -> Value
  ) -> Self where Self == TaskLocalTrait<Value> {
    TaskLocalTrait(taskLocal: taskLocal, value: value)
  }
}
