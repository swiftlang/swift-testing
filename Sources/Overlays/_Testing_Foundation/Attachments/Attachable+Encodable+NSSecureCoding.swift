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

// This implementation is necessary to let the compiler disambiguate when a type
// conforms to both Encodable and NSSecureCoding. It is hidden from the DocC
// compiler because it appears redundant next to the other two implementations
// (which explicitly document what happens when a type conforms to both
// protocols.)

/// @Metadata {
///   @Available(Swift, introduced: 6.2)
///   @Available(Xcode, introduced: 26.0)
/// }
extension Attachable where Self: Encodable & NSSecureCoding {
  @_documentation(visibility: private)
  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try data(encoding: self, for: attachment).withUnsafeBytes(body)
  }

  @_documentation(visibility: private)
  public borrowing func bytes(for attachment: borrowing Attachment<Self>) throws -> Data {
    try data(encoding: self, for: attachment)
  }
}
#endif
