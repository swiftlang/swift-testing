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
    /// An estimate of the number of bytes of memory needed to store this value
    /// as an attachment.
    ///
    /// The testing library uses this property to determine if an attachment
    /// should be held in memory or should be immediately persisted to storage.
    /// Larger attachments are more likely to be persisted, but the algorithm
    /// the testing library uses is an implementation detail and is subject to
    /// change.
    ///
    /// The value of this property is approximately equal to the number of bytes
    /// that will actually be needed, or `nil` if the value cannot be computed
    /// efficiently. The default implementation of this property returns `nil`.
    ///
    /// - Complexity: O(1) unless `Self` conforms to `Collection`, in which case
    ///   up to O(_n_) where _n_ is the length of the collection.
    var estimatedAttachmentByteCount: Int? { get }

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

extension Test.Attachable where Self: ~Copyable {
  public var estimatedAttachmentByteCount: Int? {
    nil
  }
}

extension Test.Attachable where Self: Collection, Element == UInt8 {
  public var estimatedAttachmentByteCount: Int? {
    count
  }
}

extension Test.Attachable where Self: StringProtocol {
  public var estimatedAttachmentByteCount: Int? {
    // NOTE: utf8.count may be O(n) for foreign strings.
    // SEE: https://github.com/swiftlang/swift/blob/main/stdlib/public/core/StringUTF8View.swift
    utf8.count
  }
}

// MARK: - Default conformances

// Implement the protocol requirements for byte arrays and buffers so that
// developers can attach raw data when needed.
@_spi(Experimental)
extension [UInt8]: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try withUnsafeBytes(body)
  }
}

@_spi(Experimental)
extension UnsafeBufferPointer<UInt8>: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try body(.init(self))
  }
}

@_spi(Experimental)
extension UnsafeMutableBufferPointer<UInt8>: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try body(.init(self))
  }
}

@_spi(Experimental)
extension UnsafeRawBufferPointer: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try body(self)
  }
}

@_spi(Experimental)
extension UnsafeMutableRawBufferPointer: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try body(.init(self))
  }
}

@_spi(Experimental)
extension String: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var selfCopy = self
    return try selfCopy.withUTF8 { utf8 in
      try body(UnsafeRawBufferPointer(utf8))
    }
  }
}

@_spi(Experimental)
extension Substring: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var selfCopy = self
    return try selfCopy.withUTF8 { utf8 in
      try body(UnsafeRawBufferPointer(utf8))
    }
  }
}
