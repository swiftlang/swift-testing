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
@_spi(Experimental) public import Testing
public import Foundation

@_spi(Experimental)
extension Test.Attachable where Self: Encodable & NSSecureCoding {
  @_documentation(visibility: private)
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    func open(_ value: borrowing some Encodable & Test.Attachable) throws -> R {
      return try value.withUnsafeBufferPointer(for: attachment, body)
    }
    return try open(self)
  }
}
#endif
