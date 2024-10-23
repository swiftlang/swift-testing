//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental)
extension Test {
  /// A protocol describing a type that can be attached to a test report or
  /// written to disk when a test is run.
  ///
  /// To attach an attachable value to a test report or test run output, use it
  /// to initialize a new instance of ``Test/Attachment``, then call
  /// ``Test/Attachment/attach()``. An attachment can only be attached once.
  ///
  /// Generally speaking, you should not need to make new types conform to this
  /// protocol.
  // TODO: write more about this protocol, how it works, and list conforming
  // types (including discussion of the Foundation cross-import overlay.)
  public protocol Attachable: ~Copyable {
    /// A lower bound for the number of bytes that will be needed by this
    /// value's ``withUnsafeBufferPointer(for:_:)`` function is called.
    ///
    /// The testing library uses the value of this property to determine if an
    /// attachment should be written to disk immediately or can remain in memory
    /// until the current test finishes.
    ///
    /// The value of this property should be as close as possible to this
    /// value's size when represented by ``withUnsafeBufferPointer(for:_:)``
    /// without actually performing an encoding operation. If a reasonable value
    /// cannot be derived quickly and efficiently, use this property's default
    /// implementation (which provides a value of `0`.)
    var underestimatedAttachableByteCount: Int { get }

    /// Call a function and pass a buffer representing this instance to it.
    ///
    /// - Parameters:
    ///   - attachment: The attachment that is requesting a buffer (that is, the
    ///     attachment containing this instance.)
    ///   - body: A function to call. A temporary buffer containing a data
    ///     representation of this instance is passed to it.
    ///
    /// - Returns: Whatever is returned by `body`.
    ///
    /// - Throws: Whatever is thrown by `body`, or any error that prevented the
    ///   creation of the buffer.
    ///
    /// The testing library uses this function when writing an attachment to a
    /// test report or to a file on disk. The format of the buffer is
    /// implementation-defined, but should be "idiomatic" for this type: for
    /// example, if this type represents an image, it would be appropriate for
    /// the buffer to contain an image in PNG format, JPEG format, etc., but it
    /// would not be idiomatic for the buffer to contain a textual description
    /// of the image.
    borrowing func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R
  }
}

// MARK: - Default implementations

extension Test.Attachable {
  public var underestimatedAttachableByteCount: Int {
    0
  }
}

// Implement the protocol requirements for byte arrays and buffers so that
// developers can attach raw data when needed.
@_spi(Experimental)
extension [UInt8]: Test.Attachable {
  public var underestimatedAttachableByteCount: Int {
    count
  }

  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try withUnsafeBytes(body)
  }
}

@_spi(Experimental)
extension UnsafeBufferPointer<UInt8>: Test.Attachable {
  public var underestimatedAttachableByteCount: Int {
    count
  }

  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try body(.init(self))
  }
}

@_spi(Experimental)
extension UnsafeRawBufferPointer: Test.Attachable {
  public var underestimatedAttachableByteCount: Int {
    count
  }

  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try body(self)
  }
}

@_spi(Experimental)
extension String: Test.Attachable {
  public var underestimatedAttachableByteCount: Int {
    utf8.count
  }

  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var selfCopy = self
    return try selfCopy.withUTF8 { utf8 in
      try body(UnsafeRawBufferPointer(utf8))
    }
  }
}

@_spi(Experimental)
extension Substring: Test.Attachable {
  public var underestimatedAttachableByteCount: Int {
    utf8.count
  }

  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var selfCopy = self
    return try selfCopy.withUTF8 { utf8 in
      try body(UnsafeRawBufferPointer(utf8))
    }
  }
}
