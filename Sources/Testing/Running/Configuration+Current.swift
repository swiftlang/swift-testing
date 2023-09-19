//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ExperimentalTestRunning)
extension Configuration {
  /// Mutable storage for ``Configuration/current``.
  @TaskLocal
  private static var _current: Self?

  /// The currently-applied test configuration, if any.
  public static var current: Self? {
    _current
  }

  /// A type containing the mutable state tracked by ``Configuration/_all`` and,
  /// indirectly, by ``Configuration/all``.
  private struct _All: Sendable {
    /// All instances of ``Configuration`` set as current, keyed by their unique
    /// identifiers.
    var instances = [UInt64: Configuration]()

    /// The next available unique identifier for an event handler.
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

  /// Call a function while the value of ``Configuration/current`` is set.
  ///
  /// - Parameters:
  ///   - configuration: The new value to set for ``Configuration/current``.
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  static func withCurrent<R>(_ configuration: Configuration?, _ body: () throws -> R) rethrows -> R {
    let id = configuration?._addToAll()
    defer {
      configuration?._removeFromAll(identifiedBy: id)
    }
    return try $_current.withValue(configuration, operation: body)
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
  static func withCurrent<R>(_ configuration: Configuration?, _ body: () async throws -> R) async rethrows -> R {
    let id = configuration?._addToAll()
    defer {
      configuration?._removeFromAll(identifiedBy: id)
    }
    return try await $_current.withValue(configuration, operation: body)
  }
}
