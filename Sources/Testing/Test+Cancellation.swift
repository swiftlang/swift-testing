//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A protocol describing cancellable tests and test cases.
///
/// This protocol is used to abstract away the common implementation of test and
/// test case cancellation.
protocol TestCancellable: Sendable {
  /// The task associated with this instance, if any, guarded by a lock.
  var unsafeCurrentTask: Locked<UnsafeCurrentTask?> { get set }

  /// Make an instance of ``Event/Kind`` appropriate for `self`.
  ///
  /// - Parameters:
  ///   - skipInfo: The ``SkipInfo`` structure describing the cancellation.
  ///
  /// - Returns: An instance of ``Event/Kind`` that describes the cancellation.
  func makeCancelledEventKind(with skipInfo: SkipInfo) -> Event.Kind
}

extension TestCancellable {
  /// Call a function while the ``unsafeCurrentTask`` property of this instance
  /// is set to the current task.
  ///
  /// - Parameters:
  ///   - body: The function to invoke.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  ///
  /// This function sets the ``unsafeCurrentTask`` property, calls `body`, then
  /// sets ``unsafeCurrentTask`` back to its previous value.
  func withUnsafeCurrentTask<R>(_ body: () async throws -> R) async rethrows -> R {
    if #available(_asyncUnsafeCurrentTaskAPI, *) {
      return try await _Concurrency.withUnsafeCurrentTask { task in
        let oldTask = task
        unsafeCurrentTask.withLock { $0 = task }
        defer {
          unsafeCurrentTask.withLock { $0 = oldTask }
        }
        return try await body()
      }
    } else {
      return try await body()
    }
  }
}

/// The common implementation of cancellation for ``Test`` and ``Test/Case``.
///
/// - Parameters:
///   - cancellableValue: The test or test case to cancel, or `nil` if neither
///     is set and we need fallback handling.
///   - comment: A comment describing why you are cancelling the test/case.
///   - sourceLocation: The source location to which the testing library will
///     attribute the cancellation.
///
/// - Throws: An instance of ``SkipInfo`` describing the cancellation.
private func _cancel(_ cancellableValue: (some TestCancellable)?, _ comment: Comment?, sourceLocation: SourceLocation) throws -> Never {
  let sourceContext = SourceContext(backtrace: .current(), sourceLocation: sourceLocation)
  let skipInfo = SkipInfo(comment: comment, sourceContext: sourceContext)

  if let cancellableValue {
    // If the current test case is still running, cancel its task and clear its
    // task property (which signals that it has been cancelled.)
    let wasRunning = cancellableValue.unsafeCurrentTask.withLock { task in
      let result = (task != nil)
      task?.cancel()
      task = nil
      return result
    }

    // If we just cancelled the current test case's task, post a corresponding
    // event with the relevant skip info.
    if wasRunning {
      Event.post(cancellableValue.makeCancelledEventKind(with: skipInfo))
    }
  } else {
    // The current task isn't associated with a test case, so just cancel it
    // and (try to) record an API misuse issue.
    withUnsafeCurrentTask { task in
      task?.cancel()
    }

    let issue = Issue(
      kind: .apiMisused,
      comments: ["Attempted to cancel the current test case, but there is no test case associated with the current task."] + Array(comment),
      sourceContext: sourceContext
    )
    issue.record()
  }

  throw skipInfo
}

// MARK: - Test cancellation

extension Test: TestCancellable {
  /// Cancel the current test.
  ///
  /// - Parameters:
  ///   - comment: A comment describing why you are cancelling the test.
  ///   - sourceLocation: The source location to which the testing library will
  ///     attribute the cancellation.
  ///
  /// - Throws: An error indicating that the current test case has been
  ///   cancelled.
  ///
  /// The testing library runs each test in its own task. When you call this
  /// function, the testing library cancels the task associated with the current
  /// test:
  ///
  /// ```swift
  /// @Test func `Food truck is well-stocked`() throws {
  ///   guard businessHours.contains(.now) else {
  ///     try Test.cancel("We're off the clock.")
  ///   }
  ///   // ...
  /// }
  /// ```
  ///
  /// If the current test is parameterized, all of its test cases are
  /// cancelled. If the current test is a suite, all of its tests are cancelled.
  /// If the current test has already been cancelled, this function throws an
  /// error but does not attempt to cancel the test a second time.
  ///
  /// To cancel the current test case but leave other test cases of the current
  /// test alone, call ``Test/Case/cancel(_:sourceLocation:)`` instead.
  ///
  /// - Important: If the current task is not associated with a test (for
  ///   example, because it was created with [`Task.detached(name:priority:operation:)`](https://developer.apple.com/documentation/swift/task/detached(name:priority:operation:)-795w1))
  ///   this function records an issue and cancels the current task.
  @_spi(Experimental)
  @available(_asyncUnsafeCurrentTaskAPI, *)
  public static func cancel(
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> Never {
    try _cancel(Test.current, comment, sourceLocation: sourceLocation)
  }

  func makeCancelledEventKind(with skipInfo: SkipInfo) -> Event.Kind {
    .testCancelled(skipInfo)
  }
}

// MARK: - Test case cancellation

extension Test.Case: TestCancellable {
  /// Cancel the current test case.
  ///
  /// - Parameters:
  ///   - comment: A comment describing why you are cancelling the test case.
  ///   - sourceLocation: The source location to which the testing library will
  ///     attribute the cancellation.
  ///
  /// - Throws: An error indicating that the current test case has been
  ///   cancelled.
  ///
  /// The testing library runs each test case of a test in its own task. When
  /// you call this function, the testing library cancels the task associated
  /// with the current test case:
  ///
  /// ```swift
  /// @Test(arguments: [Food.burger, .fries, .iceCream])
  /// func `Food truck is well-stocked`(_ food: Food) throws {
  ///   if food == .iceCream && Season.current == .winter {
  ///     try Test.Case.cancel("It's too cold for ice cream.")
  ///   }
  ///   // ...
  /// }
  /// ```
  ///
  /// If the current test is parameterized, the test's other test cases continue
  /// running. If the current test case has already been cancelled, this
  /// function throws an error but does not attempt to cancel the test case a
  /// second time.
  ///
  /// To cancel all test cases in the current test, call
  /// ``Test/cancel(_:sourceLocation:)`` instead.
  ///
  /// - Important: If the current task is not associated with a test case (for
  ///   example, because it was created with [`Task.detached(name:priority:operation:)`](https://developer.apple.com/documentation/swift/task/detached(name:priority:operation:)-795w1))
  ///   this function records an issue and cancels the current task.
  @_spi(Experimental)
  @available(_asyncUnsafeCurrentTaskAPI, *)
  public static func cancel(
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> Never {
    if let test = Test.current, !test.isParameterized {
      // The current test is not parameterized, so cancel the whole test rather
      // than just the test case.
      try _cancel(test, comment, sourceLocation: sourceLocation)
    }

    // Cancel the current test case (if it's nil, that's the API misuse path.)
    try _cancel(Test.Case.current, comment, sourceLocation: sourceLocation)
  }

  func makeCancelledEventKind(with skipInfo: SkipInfo) -> Event.Kind {
    .testCaseCancelled(skipInfo)
  }
}
