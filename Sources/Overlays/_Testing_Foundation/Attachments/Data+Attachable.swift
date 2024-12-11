//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation)
public import Testing
public import Foundation

/// @Metadata {
///   @Available(Swift, introduced: 6.2)
/// }
extension Data: Attachable {
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.2)
  /// }
  public typealias AttachmentMetadata = Never?

  /// @Metadata {
  ///   @Available(Swift, introduced: 6.2)
  /// }
  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try withUnsafeBytes(body)
  }
}
#endif
