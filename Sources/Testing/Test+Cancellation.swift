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
  /// Make an instance of ``Event/Kind`` appropriate for `self`.
  ///
  /// - Parameters:
  ///   - skipInfo: The ``SkipInfo`` structure describing the cancellation.
  ///
  /// - Returns: An instance of ``Event/Kind`` that describes the cancellation.
  static func makeCancelledEventKind(with skipInfo: SkipInfo) -> Event.Kind
}

// MARK: - Tracking the current task

/// A structure describing a reference to a task that is associated with some
/// ``TestCancellable`` value.
private struct _TaskReference: Sendable {
  /// The unsafe underlying reference to the associated task.
  private nonisolated(unsafe) var _unsafeCurrentTask = Locked<UnsafeCurrentTask?>()

  init() {
    let unsafeCurrentTask = withUnsafeCurrentTask { $0 }
    _unsafeCurrentTask = Locked(rawValue: unsafeCurrentTask)
  }

  /// Take this instance's reference to its associated task.
  ///
  /// - Returns: An `UnsafeCurrentTask` instance, or `nil` if it was already
  ///   taken or if it was never available.
  ///
  /// This function consumes the reference to the task. After the first call,
  /// subsequent calls on the same instance return `nil`.
  func takeUnsafeCurrentTask() -> UnsafeCurrentTask? {
    _unsafeCurrentTask.withLock { unsafeCurrentTask in
      let result = unsafeCurrentTask
      unsafeCurrentTask = nil
      return result
    }
  }
}

/// A dictionary of tasks tracked per-task and keyed by types that conform to
/// ``TestCancellable``.
@TaskLocal
private var _currentTaskReferences = [ObjectIdentifier: _TaskReference]()

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
  func withCancellationHandling<R>(_ body: () async throws -> R) async rethrows -> R {
    var currentTaskReferences = _currentTaskReferences
    currentTaskReferences[ObjectIdentifier(Self.self)] = _TaskReference()
    return try await $_currentTaskReferences.withValue(currentTaskReferences) {
      try await withTaskCancellationHandler {
        try await body()
      } onCancel: {
        // The current task was cancelled, so cancel the test case or test
        // associated with it.
        if Test.Case.current != nil {
          _ = try? Test.Case.cancel(comment: nil, sourceLocation: nil)
        } else if let test = Test.current {
          _ = try? _cancel(test, comment: nil, sourceLocation: nil)
        }
      }
    }
  }
}

// MARK: -

/// The common implementation of cancellation for ``Test`` and ``Test/Case``.
///
/// - Parameters:
///   - cancellableValue: The test or test case to cancel, or `nil` if neither
///     is set and we need fallback handling.
///   - comment: A comment describing why you are cancelling the test/case.
///   - sourceLocation: The source location to which the testing library will
///     attribute the cancellation, if available.
///
/// - Throws: An instance of ``SkipInfo`` describing the cancellation.
private func _cancel<T>(_ cancellableValue: T?, comment: Comment?, sourceLocation: SourceLocation?) throws -> Never where T: TestCancellable {
  let sourceContext = SourceContext(backtrace: .current(), sourceLocation: sourceLocation)
  let skipInfo = SkipInfo(comment: comment, sourceContext: sourceContext)

  if cancellableValue != nil {
    // If the current test case is still running, cancel its task and clear its
    // task property (which signals that it has been cancelled.)
    let task = _currentTaskReferences[ObjectIdentifier(T.self)]?.takeUnsafeCurrentTask()
    task?.cancel()

    // If we just cancelled the current test case's task, post a corresponding
    // event with the relevant skip info.
    if task != nil {
      Event.post(T.makeCancelledEventKind(with: skipInfo))
    }
  } else {
    // The current task isn't associated with a test case, so just cancel it
    // and (try to) record an API misuse issue.
    withUnsafeCurrentTask { task in
      task?.cancel()
    }

    let issue = if ExitTest.current != nil {
      // Attempted to cancel the test or test case from within an exit test. The
      // semantics of such an action aren't yet well-defined.
      Issue(
        kind: .apiMisused,
        comments: ["Attempted to cancel the current test or test case from within an exit test."] + Array(comment),
        sourceContext: sourceContext
      )
    } else {
      Issue(
        kind: .apiMisused,
        comments: ["Attempted to cancel the current test or test case, but one is not associated with the current task."] + Array(comment),
        sourceContext: sourceContext
      )
    }
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
  /// If the current test is parameterized, all of its pending and running test
  /// cases are cancelled. If the current test is a suite, all of its pending
  /// and running tests are cancelled. If you have already cancelled the current
  /// test or if it has already finished running, this function throws an error
  /// but does not attempt to cancel the test a second time.
  ///
  /// - Note: You cannot cancel a test from within the body of an [exit test](doc:exit-testing).
  ///
  /// To cancel the current test case but leave other test cases of the current
  /// test alone, call ``Test/Case/cancel(_:sourceLocation:)`` instead.
  ///
  /// - Important: If the current task is not associated with a test (for
  ///   example, because it was created with [`Task.detached(name:priority:operation:)`](https://developer.apple.com/documentation/swift/task/detached(name:priority:operation:)-795w1))
  ///   this function records an issue and cancels the current task.
  @_spi(Experimental)
  public static func cancel(_ comment: Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation) throws -> Never {
    try _cancel(Test.current, comment: comment, sourceLocation: sourceLocation)
  }

  static func makeCancelledEventKind(with skipInfo: SkipInfo) -> Event.Kind {
    .testCancelled(skipInfo)
  }
}

// MARK: - Test case cancellation

extension Test.Case: TestCancellable {
  /// The implementation of ``cancel(_:sourceLocation:)``, but able to take a
  /// `nil` value as its `sourceLocation` argument.
  ///
  /// - Parameters:
  ///   - comment: A comment describing why you are cancelling the test.
  ///   - sourceLocation: The source location to which the testing library will
  ///     attribute the cancellation.
  ///
  /// - Throws: An error indicating that the current test case has been
  ///   cancelled.
  ///
  /// This overload of `cancel()` is factored out so we can call it with a `nil`
  /// source location in ``withCancellationHandling(_:)``.
  fileprivate static func cancel(comment: Comment?, sourceLocation: SourceLocation?) throws -> Never {
    if let test = Test.current, !test.isParameterized {
      // The current test is not parameterized, so cancel the whole test rather
      // than just the test case.
      try _cancel(test, comment: comment, sourceLocation: sourceLocation)
    }

    // Cancel the current test case (if it's nil, that's the API misuse path.)
    try _cancel(Test.Case.current, comment: comment, sourceLocation: sourceLocation)
  }

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
  /// - Note: You cannot cancel a test case from within the body of an [exit test](doc:exit-testing).
  ///
  /// To cancel all test cases in the current test, call
  /// ``Test/cancel(_:sourceLocation:)`` instead.
  ///
  /// - Important: If the current task is not associated with a test case (for
  ///   example, because it was created with [`Task.detached(name:priority:operation:)`](https://developer.apple.com/documentation/swift/task/detached(name:priority:operation:)-795w1))
  ///   this function records an issue and cancels the current task.
  //@_spi(Experimental)
  public static func cancel(_ comment: Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation) throws -> Never {
    try cancel(comment: comment, sourceLocation: sourceLocation)
  }

  static func makeCancelledEventKind(with skipInfo: SkipInfo) -> Event.Kind {
    .testCaseCancelled(skipInfo)
  }
}
