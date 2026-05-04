//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Benchmark {
  /// The interface a benchmark uses to communicate with the host measuring it.
  ///
  /// A host provides an instance of a type conforming to this protocol each time it
  /// invokes a ``Benchmark/Body``. The testing library makes it available as
  /// ``Benchmark/currentContext`` for the duration of the invocation, so a
  /// benchmark can reach its context without taking it as a parameter — which is
  /// what ``Benchmark/measure(_:)`` does.
  public protocol Context: AnyObject {
    /// The number of times the benchmark should repeat its work before returning.
    ///
    /// A benchmark measuring an operation faster than the host's clock resolution
    /// should perform that operation this many times so that the host can amortize
    /// its measurement overhead. Hosts divide metrics whose
    /// ``Benchmark/Metric/scalesWithIterationCount`` property is `true` by this
    /// value to recover a per-operation figure.
    var innerIterationCount: Int { get }

    /// Begin measuring, discarding any time already measured.
    ///
    /// A benchmark that performs setup work which should not be measured begins
    /// measuring once that work is complete. Calling this function more than once
    /// during a single invocation restarts measurement; hosts must tolerate that.
    ///
    /// Prefer ``Benchmark/measure(_:)``, which pairs this function with
    /// ``stopMeasurement()`` for you.
    func startMeasurement()

    /// Stop measuring.
    ///
    /// A benchmark that performs teardown work which should not be measured stops
    /// measuring before beginning that work. Calling this function when measurement
    /// is not in progress does nothing.
    ///
    /// Prefer ``Benchmark/measure(_:)``, which pairs this function with
    /// ``startMeasurement()`` for you.
    func stopMeasurement()
  }
}

// MARK: - The current context

extension Benchmark {
  /// A wrapper that allows a context to be stored in a task-local value without
  /// requiring ``Benchmark/Context`` to inherit from `Sendable`.
  ///
  /// A task-local's value must be sendable, but requiring that of every context
  /// would push an implementation detail of this storage onto every host. The
  /// wrapper is safe because a benchmark's body is synchronous: it cannot create a
  /// child task that would observe the bound value concurrently with the task that
  /// bound it.
  private struct _ContextBox: @unchecked Sendable {
    var context: any Context
  }

  /// Storage for ``currentContext``.
  @TaskLocal
  private static var _currentContext: _ContextBox?

  /// The context of the benchmark running on the current task, or `nil` if no
  /// benchmark is running.
  ///
  /// The testing library binds this value around each invocation of a
  /// ``Benchmark/Body``.
  public static var currentContext: (any Context)? {
    _currentContext?.context
  }

  /// Bind ``currentContext`` for the duration of a function.
  ///
  /// - Parameters:
  ///   - context: The context to bind.
  ///   - body: The function to perform.
  ///
  /// - Returns: Whatever `body` returns.
  ///
  /// - Throws: Whatever `body` throws.
  static func withCurrentContext<R>(_ context: any Context, perform body: () throws -> R) rethrows -> R {
    try $_currentContext.withValue(_ContextBox(context: context), operation: body)
  }
}
