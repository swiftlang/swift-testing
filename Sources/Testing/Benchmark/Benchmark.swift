//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A namespace for the types involved in measuring benchmarks.
///
/// - Warning: Benchmark support is experimental. Its interface is subject to
///   change.
public enum Benchmark: Sendable {}

// MARK: - Narrowing what is measured

extension Benchmark {
  /// Measure only the work performed by a closure.
  ///
  /// - Parameters:
  ///   - body: The work to measure.
  ///
  /// - Returns: Whatever `body` returns.
  ///
  /// - Throws: Whatever `body` throws.
  ///
  /// A benchmark that performs setup or teardown work which should not be
  /// measured can wrap the part that should be:
  ///
  /// ```swift
  /// @Benchmark func sorting() {
  ///   var values = makeUnsortedValues()
  ///   Benchmark.measure {
  ///     values.sort()
  ///   }
  ///   precondition(values.isSorted)
  /// }
  /// ```
  ///
  /// A benchmark that does not call this function is measured in its entirety.
  /// Calling it more than once measures only the last region, since starting
  /// measurement discards any time already measured.
  ///
  /// Calling this function outside of a running benchmark performs `body` and
  /// measures nothing.
  @discardableResult
  public static func measure<R, E>(_ body: () throws(E) -> R) throws(E) -> R where E: Error {
    guard let context = currentContext else {
      return try body()
    }
    context.startMeasurement()
    defer {
      context.stopMeasurement()
    }
    return try body()
  }
}
