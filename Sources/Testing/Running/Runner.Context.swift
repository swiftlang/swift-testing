//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Runner {
  /// A type which collects the task-scoped context for a running ``Runner``
  /// instance, the tests it runs, and other objects it interacts with.
  ///
  /// This type is intended for use via the task-local
  /// ``Runner/Context/current`` property.
  fileprivate struct Context: Sendable {
    /// The runner that is running on the current task, if any.
    var runner: Runner?

    /// The test that is running on the current task, if any.
    var test: Test?

    /// The test case that is running on the current task, if any.
    var testCase: Test.Case?

    /// The context related to the runner running on the current task.
    @TaskLocal
    static var current: Self = .init()
  }
}

// MARK: - Current runner

extension Runner {
  /// The runner that is running on the current task, if any.
  public static var current: Self? {
    Context.current.runner
  }

  /// Call a function while the value of ``Runner/current`` is set.
  ///
  /// - Parameters:
  ///   - runner: The new value to set for ``Runner/current``.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  static func withCurrent<R>(_ runner: Self, perform body: () throws -> R) rethrows -> R {
    let id = runner._addToAll()
    defer {
      runner._removeFromAll(identifiedBy: id)
    }

    var context = Context.current
    context.runner = runner
    return try Context.$current.withValue(context, operation: body)
  }

  /// Call a function while the value of ``Runner/current`` is set.
  ///
  /// - Parameters:
  ///   - runner: The new value to set for ``Runner/current``.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  static func withCurrent<R>(_ runner: Self, perform body: () async throws -> R) async rethrows -> R {
    let id = runner._addToAll()
    defer {
      runner._removeFromAll(identifiedBy: id)
    }

    var context = Context.current
    context.runner = runner
    return try await Context.$current.withValue(context, operation: body)
  }

  /// A type containing the mutable state tracked by ``Runner/_all`` and,
  /// indirectly, by ``Runner/all``.
  private struct _All: Sendable {
    /// All instances of ``Runner`` set as current, keyed by their unique
    /// identifiers.
    var instances = [UInt64: Runner]()

    /// The next available unique identifier for an event handler.
    var nextID: UInt64 = 0
  }

  /// Mutable storage for ``Runner/all``.
  @Locked
  private static var _all = _All()

  /// A collection containing all instances of this type that are currently set
  /// as the current runner for a task.
  ///
  /// This property is used when an event is posted in a context where the value
  /// of ``Runner/current`` is `nil`, such as from a detached task.
  static var all: some Collection<Self> {
    _all.instances.values
  }

  /// Add this instance to ``Runner/all``.
  ///
  /// - Returns: A unique number identifying `self` that can be
  ///   passed to `_removeFromAll(identifiedBy:)`` to unregister it.
  private func _addToAll() -> UInt64 {
    Self.$_all.withLock { all in
      let id = all.nextID
      all.nextID += 1
      all.instances[id] = self
      return id
    }
  }

  /// Remove this instance from ``Runner/all``.
  ///
  /// - Parameters:
  ///   - id: The unique identifier of this instance, as previously returned by
  ///     `_addToAll()`. If `nil`, this function has no effect.
  private func _removeFromAll(identifiedBy id: UInt64?) {
    if let id {
      Self.$_all.withLock { all in
        _ = all.instances.removeValue(forKey: id)
      }
    }
  }
}

// MARK: - Current test and test case

extension Test {
  /// The test that is running on the current task, if any.
  public static var current: Self? {
    Runner.Context.current.test
  }

  /// Call a function while the value of ``Test/current`` is set.
  ///
  /// - Parameters:
  ///   - test: The new value to set for ``Test/current``.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  static func withCurrent<R>(_ test: Self, perform body: () throws -> R) rethrows -> R {
    var context = Runner.Context.current
    context.test = test
    return try Runner.Context.$current.withValue(context, operation: body)
  }

  /// Call a function while the value of ``Test/current`` is set.
  ///
  /// - Parameters:
  ///   - test: The new value to set for ``Test/current``.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  static func withCurrent<R>(_ test: Self, perform body: () async throws -> R) async rethrows -> R {
    var context = Runner.Context.current
    context.test = test
    return try await Runner.Context.$current.withValue(context, operation: body)
  }
}

extension Test.Case {
  /// The test case that is running on the current task, if any.
  public static var current: Self? {
    Runner.Context.current.testCase
  }

  /// Call a function while the value of ``Test/Case/current`` is set.
  ///
  /// - Parameters:
  ///   - testCase: The new value to set for ``Test/Case/current``.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  static func withCurrent<R>(_ testCase: Self, perform body: () throws -> R) rethrows -> R {
    var context = Runner.Context.current
    context.testCase = testCase
    return try Runner.Context.$current.withValue(context, operation: body)
  }

  /// Call a function while the value of ``Test/Case/current`` is set.
  ///
  /// - Parameters:
  ///   - testCase: The new value to set for ``Test/Case/current``.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  static func withCurrent<R>(_ testCase: Self, perform body: () async throws -> R) async rethrows -> R {
    var context = Runner.Context.current
    context.testCase = testCase
    return try await Runner.Context.$current.withValue(context, operation: body)
  }
}
