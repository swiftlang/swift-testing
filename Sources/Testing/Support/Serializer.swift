//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2025 Apple Inc. and the Swift project authors
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
  /// The maximum number of work items that may run concurrently.
  nonisolated let maximumWidth: Int

  /// The number of scheduled work items, including any currently running.
  private var _currentWidth = 0

  /// Continuations for any scheduled work items that haven't started yet.
  private var _continuations = [CheckedContinuation<Void, Never>]()

  init(maximumWidth: Int = 1) {
    self.maximumWidth = maximumWidth
  }

  /// Run a work item serially after any previously-scheduled work items.
  ///
  /// - Parameters:
  ///     - workItem: A closure to run.
  ///
  /// - Returns: Whatever is returned from `workItem`.
  ///
  /// - Throws: Whatever is thrown by `workItem`.
  func run<R>(_ workItem: @Sendable @isolated(any) () async throws -> R) async rethrows -> R where R: Sendable {
    _currentWidth += 1
    defer {
      // Resume the next scheduled closure.
      if !_continuations.isEmpty {
        let continuation = _continuations.removeFirst()
        continuation.resume()
      }

      _currentWidth -= 1
    }

    await withCheckedContinuation { continuation in
      if _currentWidth <= maximumWidth {
        // Nothing else was scheduled, so we can resume immediately.
        continuation.resume()
      } else {
        // Something was scheduled, so add the continuation to the
        // list. When it resumes, we can run.
        _continuations.append(continuation)
      }
    }

    return try await workItem()
  }
}

