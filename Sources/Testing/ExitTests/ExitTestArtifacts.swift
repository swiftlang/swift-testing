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
/// Both ``expect(exitsWith:observing:_:sourceLocation:performing:)`` and
/// ``require(exitsWith:observing:_:sourceLocation:performing:)`` return
/// instances of this type.
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
  /// ``expect(exitsWith:observing:_:sourceLocation:performing:)`` or to
  /// ``require(exitsWith:observing:_:sourceLocation:performing:)``. You can
  /// compare two instances of ``ExitCondition`` with
  /// ``/Swift/Optional/==(_:_:)``.
  public var exitCondition: ExitCondition

  /// All bytes written to the standard output stream of the exit test before
  /// it exited.
  ///
  /// The value of this property may contain any arbitrary sequence of bytes,
  /// including sequences that are not valid UTF-8 and cannot be decoded by
  /// [`String.init(cString:)`](https://developer.apple.com/documentation/swift/string/init(cstring:)-6kr8s).
  /// Consider using [`String.init(validatingCString:)`](https://developer.apple.com/documentation/swift/string/init(validatingcstring:)-992vo)
  /// instead.
  ///
  /// When checking the value of this property, keep in mind that the standard
  /// output stream is globally accessible, and any code running in an exit
  /// test may write to it including including the operating system and any
  /// third-party dependencies you have declared in your package. Rather than
  /// comparing the value of this property with [`==`](https://developer.apple.com/documentation/swift/array/==(_:_:)),
  /// use [`contains(_:)`](https://developer.apple.com/documentation/swift/collection/contains(_:))
  /// to check if expected output is present.
  ///
  /// To enable gathering output from the standard output stream during an
  /// exit test, pass `\.standardOutputContent` in the `observedValues`
  /// argument of ``expect(exitsWith:observing:_:sourceLocation:performing:)``
  /// or ``require(exitsWith:observing:_:sourceLocation:performing:)``.
  ///
  /// If you did not request standard output content when running an exit test,
  /// the value of this property is the empty array.
  public var standardOutputContent: [UInt8] = []

  /// All bytes written to the standard error stream of the exit test before
  /// it exited.
  ///
  /// The value of this property may contain any arbitrary sequence of bytes,
  /// including sequences that are not valid UTF-8 and cannot be decoded by
  /// [`String.init(cString:)`](https://developer.apple.com/documentation/swift/string/init(cstring:)-6kr8s).
  /// Consider using [`String.init(validatingCString:)`](https://developer.apple.com/documentation/swift/string/init(validatingcstring:)-992vo)
  /// instead.
  ///
  /// When checking the value of this property, keep in mind that the standard
  /// output stream is globally accessible, and any code running in an exit
  /// test may write to it including including the operating system and any
  /// third-party dependencies you have declared in your package. Rather than
  /// comparing the value of this property with [`==`](https://developer.apple.com/documentation/swift/array/==(_:_:)),
  /// use [`contains(_:)`](https://developer.apple.com/documentation/swift/collection/contains(_:))
  /// to check if expected output is present.
  ///
  /// To enable gathering output from the standard error stream during an exit
  /// test, pass `\.standardErrorContent` in the `observedValues` argument of
  /// ``expect(exitsWith:observing:_:sourceLocation:performing:)`` or
  /// ``require(exitsWith:observing:_:sourceLocation:performing:)``.
  ///
  /// If you did not request standard error content when running an exit test,
  /// the value of this property is the empty array.
  public var standardErrorContent: [UInt8] = []

  @_spi(ForToolsIntegrationOnly)
  public init(exitCondition: ExitCondition) {
    self.exitCondition = exitCondition
  }
}
