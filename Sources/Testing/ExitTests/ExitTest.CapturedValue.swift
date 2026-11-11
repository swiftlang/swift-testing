//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

@_spi(ForToolsIntegrationOnly)
#if SWT_NO_EXIT_TESTS
@_unavailableInEmbedded
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
extension ExitTest {
  /// A type representing a value captured by an exit test's body.
  ///
  /// An instance of this type may represent the actual value that was captured
  /// when the exit test was invoked. In the child process created by the
  /// current exit test handler, instances will initially only have the type of
  /// the value, but not the value itself.
  ///
  /// Instances of this type are created automatically by the testing library
  /// for all elements in an exit test body's capture list and are stored in the
  /// exit test's ``capturedValues`` property. For example, given the following
  /// exit test:
  ///
  /// ```swift
  /// await #expect(processExitsWith: .failure) { [a = a as T, b = b as U, c = c as V] in
  ///   ...
  /// }
  /// ```
  ///
  /// There are three captured values in its ``capturedValues`` property. These
  /// values are captured at the time the exit test is called, as they would be
  /// if the closure were called locally.
  ///
  /// The current exit test handler is responsible for encoding and decoding
  /// instances of this type. When the handler is called, it is passed an
  /// instance of ``ExitTest``. The handler encodes the values in that
  /// instance's ``capturedValues`` property, then passes the encoded forms of
  /// those values to the child process. The encoding format and message-passing
  /// interface are implementation details of the exit test handler.
  ///
  /// When the child process calls ``ExitTest/find(identifiedBy:)``, it receives
  /// an instance of ``ExitTest`` whose ``capturedValues`` property contains
  /// type information but no values. The child process decodes the values it
  /// encoded in the parent process and then updates the ``wrappedValue``
  /// property of each element in the array before calling the exit test's body.
  public protocol CapturedValue: Sendable {
    /// The type of the underlying value.
    associatedtype Wrapped: Codable & Sendable

    /// The underlying value captured by this instance at runtime.
    ///
    /// In a child process created by the current exit test handler, the value
    /// of this property is `nil` until the entry point sets it.
    var wrappedValue: Wrapped? { get set }
  }

  /// A concrete implementation of the ``CapturedValue`` protocol.
  ///
  /// This type is not part of the public interface of the testing library.
  /// Tools SPI uses the ``CapturedValue`` protocol instead.
  struct _CapturedValue<Wrapped>: Sendable, CapturedValue where Wrapped: Codable & Sendable {
    /// The type of the underlying value.
    typealias Wrapped = Wrapped

    var wrappedValue: Wrapped?
  }
}

#if !SWT_NO_EXIT_TESTS
// MARK: - Collection conveniences

extension ExitTest {
  /// Cast the elements in a collection to a tuple of their wrapped values.
  ///
  /// - Parameters:
  ///   - collection
  ///
  /// - Returns: A tuple containing the wrapped values of the elements in
  ///   `collection`.
  ///
  /// - Throws: If an expected value could not be found or was not of the
  ///   type the caller expected.
  ///
  /// This function assumes that the entry point function has already set the
  /// ``wrappedValue`` property of each element in `collection`.
  static func takeCapturedValues<each T, C>(from collection: C) -> (repeat each T) where C: Collection<any CapturedValue> {
    func nextValue<U>(
      as type: U.Type,
      from capturedValues: inout C.SubSequence
    ) -> U {
      // Get the next captured value in the collection. If we run out of values
      // before running out of parameter pack elements, then something in the
      // exit test handler or entry point is likely broken.
      guard let wrappedValue = capturedValues.first?.wrappedValue else {
        let actualCount = collection.count
        let expectedCount = parameterPackCount(repeat (each T).self)
        fatalError("Found fewer captured values (\(actualCount)) than expected (\(expectedCount)) when passing them to the current exit test.")
      }

      // Next loop, get the next element. (We're mutating a subsequence, not
      // self, so this is generally an O(1) operation.)
      capturedValues = capturedValues.dropFirst()

      // Make sure the value is of the correct type. If it's not, that's also
      // probably a problem with the exit test handler or entry point.
      guard let wrappedValue = wrappedValue as? U else {
        fatalError("Expected captured value at index \(capturedValues.startIndex) with type '\(String(describingForTest: U.self))', but found an instance of '\(String(describingForTest: Swift.type(of: wrappedValue)))' instead.")
      }
      
      return wrappedValue
    }

    var capturedValues = collection[...]
    return (repeat nextValue(as: (each T).self, from: &capturedValues))
  }
}
#endif

