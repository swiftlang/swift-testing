//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing the result of an exit test after it has exited and
/// returned control to the calling test function.
///
/// Both ``expect(exitsWith:_:sourceLocation:performing:)`` and
/// ``require(exitsWith:_:sourceLocation:performing:)`` return instances of
/// this type.
///
/// - Warning: The name of this type is still unstable and subject to change.
@_spi(Experimental)
#if SWT_NO_EXIT_TESTS
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
public struct ExitTestArtifacts: Sendable {
  /// The exit condition the exit test exited with.
  ///
  /// When the exit test passes, the value of this property is equal to the
  /// value of the `expectedExitCondition` argument passed to
  /// ``expect(exitsWith:_:sourceLocation:performing:)`` or to
  /// ``require(exitsWith:_:sourceLocation:performing:)``. You can compare two
  /// instances of ``ExitCondition`` with ``/Swift/Optional/==(_:_:)``.
  public var exitCondition: ExitCondition

  @_spi(ForToolsIntegrationOnly)
  public init(exitCondition: ExitCondition) {
    self.exitCondition = exitCondition
  }
}
