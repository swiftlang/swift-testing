//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_FOUNDATION && !SWT_NO_CODABLE
@_spi(ForToolsIntegrationOnly) public import Testing
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
@available(swift, deprecated: 100000.0, message: "Use 'Attachment.init(encoding:as:named:sourceLocation:)' instead.")
extension Attachable where Self: Encodable & NSSecureCoding {
  @_documentation(visibility: private)
  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    let attachment = try Attachment(encoding: attachment.attachableValue, as: nil as AttachableEncodingFormat?, named: attachment.preferredName, sourceLocation: attachment.sourceLocation)
    return try attachment.withUnsafeBytes(body)
  }
}
#endif
