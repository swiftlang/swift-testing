//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type whose instances can run a series of work items in order with
/// occasional "barrier" items that run in exclusion.
///
/// When a work item is scheduled on an instance of this type, it runs after any
/// previously-scheduled work items. If it suspends, subsequently-scheduled work
/// items do not start running; they must wait until the suspended work item
/// either returns or throws an error.
final actor WorkGroup {
  /// The number of scheduled concurrent work items, including (possibly) one
  /// that is currently running.
  private var _scheduledConcurrentCount = 0

  /// The number of scheduled barrier work items, including (possibly) one that
  /// is currently running.
  private var _scheduledBarrierCount = 0

  /// A structure representing one or more work items that have been scheduled
  /// and will run later.
  ///
  /// All work items represented by an instance of this type can run in parallel
  /// with each other, but not necessarily with work items represented by
  /// another instance.
  private enum _Slice: Sendable {
    /// One or more work items that can run concurrently.
    ///
    /// - Parameters:
    ///   - continuations: The continuations for all work items.
    case concurrent(_ continuations: [CheckedContinuation<Void, Never>])

    /// A barrier work item that must run serially with respect to other work
    /// items.
    ///
    /// - Parameters:
    ///   - continuation: The continuation for the barrier work item.
    case barrier(_ continuation: CheckedContinuation<Void, Never>)

    /// Whether or not this instance represents a barrier work item.
    var isBarrier: Bool {
      if case .barrier = self {
        return true
      }
      return false
    }

    /// Resume all continuations in this instance.
    consuming func resume() {
      switch self {
      case let .concurrent(continuations):
        for continuation in continuations {
          continuation.resume()
        }
      case let .barrier(continuation):
        continuation.resume()
      }
    }
  }

  /// All scheduled work items that are running or have yet to run.
  private var _slices = [_Slice]()

  /// Run a work item.
  ///
  /// - Parameters:
  ///     - isBarrier: Whether or not `workItem` is a barrier that should run in
  ///       isolation relative to other work items run in this work group.
  ///     - workItem: A closure to run.
  ///
  /// - Returns: Whatever is returned from `workItem`.
  ///
  /// - Throws: Whatever is thrown by `workItem`.
  ///
  /// This function runs `workItem` immediately _unless a barrier has been
  /// scheduled_, in which case it suspends until that barrier is finished
  /// running.
  func run<R>(isBarrier: Bool = false, _ workItem: @Sendable @isolated(any) () async throws -> R) async rethrows -> R where R: Sendable {
    if isBarrier {
      _scheduledBarrierCount += 1
    } else {
      _scheduledConcurrentCount += 1
    }
    defer {
      // Resume the next scheduled closure.
      if !_slices.isEmpty {
        let slice = _slices.removeFirst()
        slice.resume()
      }

      if isBarrier {
        _scheduledBarrierCount -= 1
      } else {
        _scheduledConcurrentCount -= 1
      }
    }

    await withCheckedContinuation { continuation in
      if isBarrier {
        if (_scheduledConcurrentCount + _scheduledBarrierCount) > 1 {
          // Something (barrier or not) other than this barrier was scheduled,
          // so this barrier must wait.
          _slices.append(.barrier(continuation))
        } else {
          // Nothing else was scheduled, so this barrier can run immediately.
          continuation.resume()
        }
      } else {
        if _scheduledBarrierCount == 0 {
          // There are no barriers scheduled, so we can run immediately.
          continuation.resume()
        } else {
          // This work item can run concurrently, so add it to the slices list.
          switch _slices.last {
          case .some(.barrier), nil:
            // The last work item scheduled was a barrier (or the list of
            // scheduled slices is empty), so start a new concurrent slice.
            _slices.append(.concurrent([continuation]))
          case var .some(.concurrent(continuations)):
            // Update the last concurrent slice to include this work item.
            continuations.append(continuation)
            _slices.removeLast()
            _slices.append(.concurrent(continuations))
          }
        }
      }
    }

    return try await workItem()
  }
}
