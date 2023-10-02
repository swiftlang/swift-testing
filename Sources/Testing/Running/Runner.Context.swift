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
    /// The configuration for the current task, if any.
    var configuration: Configuration?

    /// The test that is running on the current task, if any.
    var test: Test?

    /// The test case that is running on the current task, if any.
    var testCase: Test.Case?

    /// The context related to the runner running on the current task.
    @TaskLocal
    static var current: Self = .init()
  }
}

extension Runner {
  /// Modify the event handler of this instance's ``Configuration`` to ensure it
  /// is invoked using the current ``Context`` value.
  ///
  /// This is meant to be called prior to running tests using this instance. It
  /// allows any events posted during the call to this instance's event handler
  /// to be directed to the previously-configured event handler, if any.
  ///
  /// In practice, the primary scenario where this is important is when running
  /// the testing library's own tests.
  mutating func configureEventHandlerContext() {
    let existingContext = Context.current
    configuration.eventHandler = { [eventHandler = configuration.eventHandler] event, context in
      Context.$current.withValue(existingContext) {
        eventHandler(event, context)
      }
    }
  }
}

// MARK: - Current configuration

extension Configuration {
  /// The configuration for the current task, if any.
  public static var current: Self? {
    Runner.Context.current.configuration
  }

  /// Call a function while the value of ``Configuration/current`` is set.
  ///
  /// - Parameters:
  ///   - configuration: The new value to set for ``Configuration/current``.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  static func withCurrent<R>(_ configuration: Self, perform body: () async throws -> R) async rethrows -> R {
    let id = configuration._addToAll()
    defer {
      configuration._removeFromAll(identifiedBy: id)
    }

    var context = Runner.Context.current
    context.configuration = configuration
    return try await Runner.Context.$current.withValue(context, operation: body)
  }

  /// A type containing the mutable state tracked by ``Configuration/_all`` and,
  /// indirectly, by ``Configuration/all``.
  private struct _All: Sendable {
    /// All instances of ``Configuration`` set as current, keyed by their unique
    /// identifiers.
    var instances = [UInt64: Configuration]()

    /// The next available unique identifier for a configuration.
    var nextID: UInt64 = 0
  }

  /// Mutable storage for ``Configuration/all``.
  @Locked
  private static var _all = _All()

  /// A collection containing all instances of this type that are currently set
  /// as the current configuration for a task.
  ///
  /// This property is used when an event is posted in a context where the value
  /// of ``Configuration/current`` is `nil`, such as from a detached task.
  static var all: some Collection<Self> {
    _all.instances.values
  }

  /// Add this instance to ``Configuration/all``.
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

  /// Remove this instance from ``Configuration/all``.
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
  static func withCurrent<R>(_ testCase: Self, perform body: () async throws -> R) async rethrows -> R {
    var context = Runner.Context.current
    context.testCase = testCase
    return try await Runner.Context.$current.withValue(context, operation: body)
  }
}
