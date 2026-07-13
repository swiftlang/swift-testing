//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Trait {
  /// Constructs a trait that binds a task local value for the duration of a test
  /// or suite.
  ///
  /// - Parameters:
  ///   - taskLocal: The task local to bind the value to.
  ///   - value: The value to bind to `taskLocal`.
  ///
  ///     This value will only be evaluated if the test this
  ///     trait is applied to runs, and it will be unbound from
  ///     the task local and released once the trait is finished
  ///     providing scope for the test.
  ///
  /// - Note: You must define the task local outside the test target where the trait is used.
  public static func taskLocal<Value: Sendable>(
    _ taskLocal: TaskLocal<Value>,
    _ value: @autoclosure @escaping @Sendable () throws -> Value
  ) -> Self
  where Self == TaskLocalTrait<Value> {
    TaskLocalTrait(taskLocal: taskLocal, value: value)
  }
}

/// A type that that binds a task local value for the duration of a test or suite.
///
/// To add this trait to a test, use ``Trait/taskLocal(_:_:)``.
public struct TaskLocalTrait<Value: Sendable>: SuiteTrait, TestTrait, TestScoping {
  /// This trait's task local.
  fileprivate var taskLocal: TaskLocal<Value>

  /// This trait's value.
  fileprivate var value: @Sendable () throws -> Value

  public var isRecursive: Bool { true }

  public func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: @concurrent () async throws -> Void
  ) async throws {
    try await taskLocal.withValue(value()) {
      try await function()
    }
  }
}
