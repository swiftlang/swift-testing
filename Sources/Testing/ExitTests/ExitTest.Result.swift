//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_NO_EXIT_TESTS
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
extension ExitTest {
  /// A type representing the result of an exit test after it has exited and
  /// returned control to the calling test function.
  ///
  /// Both ``expect(exitsWith:_:sourceLocation:performing:)`` and
  /// ``require(exitsWith:_:sourceLocation:performing:)`` return instances of
  /// this type.
  public struct Result: Sendable {
    /// The exit condition the exit test exited with.
    ///
    /// When the exit test passes, the value of this property is equal to the
    /// value of the `expectedExitCondition` argument passed to
    /// ``expect(exitsWith:_:sourceLocation:performing:)`` or to
    /// ``require(exitsWith:_:sourceLocation:performing:)``. You can compare two
    /// instances of ``ExitCondition`` with ``ExitCondition/==(lhs:rhs:)``.
    public var exitCondition: ExitCondition

    /// Whatever error might have been thrown when trying to invoke the exit
    /// test that produced this result.
    ///
    /// This property is not part of the public interface of the testing
    /// library.
    var caughtError: (any Error)?

    @_spi(ForToolsIntegrationOnly)
    public init(exitCondition: ExitCondition) {
      self.exitCondition = exitCondition
    }

    /// Initialize an instance of this type representing the result of an exit
    /// test that failed to run due to a system error or other failure.
    ///
    /// - Parameters:
    ///   - exitCondition: The exit condition the exit test exited with, if
    ///     available. The default value of this argument is
    ///     ``ExitCondition/failure`` for lack of a more accurate one.
    ///   - error: The error associated with the exit test on failure, if any.
    ///
    /// If an error (e.g. a failure calling `posix_spawn()`) occurs in the exit
    /// test handler configured by the exit test's host environment, the exit
    /// test handler should throw that error. The testing library will then
    /// record it appropriately.
    ///
    /// When used with `#require(exitsWith:)`, an instance initialized with this
    /// initializer will throw `error`.
    ///
    /// This initializer is not part of the public interface of the testing
    /// library.
    init(exitCondition: ExitCondition = .failure, catching error: any Error) {
      self.exitCondition = exitCondition
      self.caughtError = error
    }

    /// Handle this instance as if it were returned from a call to `#expect()`.
    ///
    /// - Warning: This function is used to implement the `#expect()` and
    ///   `#require()` macros. Do not call it directly.
    @inlinable public func __expected() -> Self {
      self
    }

    /// Handle this instance as if it were returned from a call to `#require()`.
    ///
    /// - Warning: This function is used to implement the `#expect()` and
    ///   `#require()` macros. Do not call it directly.
    public func __required() throws -> Self {
      if let caughtError {
        throw caughtError
      }
      return self
    }
  }
}
