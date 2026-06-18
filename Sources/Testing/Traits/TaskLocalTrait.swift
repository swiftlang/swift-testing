extension Trait {
  /// Constructs a trait that overrides a task local value for the duration of a test
  /// or suite.
  ///
  /// ```swift
  /// @Suite(.taskLocal($myValue, 42))
  /// struct MyTests {
  ///   // ...
  /// }
  /// ```
  ///
  /// - Note: The task local must be defined outside the test target where the trait is used.
  ///
  /// - Parameters:
  ///   - taskLocal: The task local to override.
  ///   - value: The value to set.
  public static func taskLocal<Value>(
    _ taskLocal: TaskLocal<Value>,
    _ value: Value
  ) -> Self
  where Self == TaskLocalTrait<Value> {
    TaskLocalTrait(taskLocal: taskLocal, value: value)
  }
}

/// A type that that overrides a task local value for the scope of a test.
///
/// To add this trait to a test, use ``Trait/taskLocal(_:_:)``.
public struct TaskLocalTrait<Value: Sendable>: SuiteTrait, TestScoping, TestTrait {
  public var isRecursive: Bool { true }

  fileprivate let taskLocal: TaskLocal<Value>
  fileprivate let value: Value

  public func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: @concurrent () async throws -> Void
  ) async throws {
    try await taskLocal.withValue(value, operation: function)
  }
}
