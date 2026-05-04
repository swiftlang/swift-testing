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
  /// The work a host is asked to measure.
  ///
  /// The testing library creates instances of this type; hosts invoke them. A host
  /// calls an instance as many times as it needs to, passing a
  /// ``Benchmark/Context`` each time, and is responsible for warmup, iteration
  /// counting, and honoring the limits in the ``Benchmark/Configuration`` it was
  /// given.
  ///
  /// A body is always synchronous. Measuring an `await` would include the cost of
  /// suspension and of any executor hops it performs, which can exceed the cost of
  /// the work under test, so `@Benchmark` does not accept an asynchronous function.
  public struct Body: Sendable {
    /// The underlying work.
    private var body: @Sendable (any Context) throws -> Void

    /// Initialize an instance of this type.
    ///
    /// - Parameters:
    ///   - body: The work to be measured.
    init(_ body: @escaping @Sendable (any Context) throws -> Void) {
      self.body = body
    }

    /// Invoke this body once.
    ///
    /// - Parameters:
    ///   - context: The context to pass to the body, and to make available to it as
    ///     ``Benchmark/currentContext``.
    ///
    /// - Throws: Any error the body throws.
    public func callAsFunction(_ context: any Context) throws {
      try Benchmark.withCurrentContext(context) {
        try body(context)
      }
    }
  }
}
