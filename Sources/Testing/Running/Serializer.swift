//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type whose instances can run a series of work items in strict order.
///
/// When a work item is scheduled on an instance of this type, it runs after any
/// previously-scheduled work items. If it suspends, subsequently-scheduled work
/// items do not start running; they must wait until the suspended work item
/// either returns or throws an error.
final actor Serializer {
  /// The number of scheduled work items, including (possibly) the one currently
  /// running.
  private var scheduledCount = 0

  /// Continuations for any scheduled work items that haven't started yet.
  private var continuations = [CheckedContinuation<Void, Never>]()

  /// Run a work item serially after any previously-scheduled work items.
  ///
  /// - Parameters:
  ///     - workItem: A closure to run.
  ///
  /// - Returns: Whatever is returned from `workItem`.
  ///
  /// - Throws: Whatever is thrown by `workItem`.
  ///
  /// - Warning: Calling this function recursively on the same instance of
  ///   ``Serializer`` will cause a deadlock.
  func run<R>(_ workItem: @Sendable () async throws -> R) async rethrows -> R {
    scheduledCount += 1
    defer {
      // Resume the next scheduled closure.
      if !continuations.isEmpty {
        let continuation = continuations.removeFirst()
        continuation.resume()
      }

      scheduledCount -= 1
    }

    await withCheckedContinuation { continuation in
      if scheduledCount == 1 {
        // Nothing else was scheduled, so we can resume immediately.
        continuation.resume()
      } else {
        // Something was scheduled, so add the continuation to the list. When it
        // resumes, we can run.
        continuations.append(continuation)
      }
    }

    return try await workItem()
  }
}

