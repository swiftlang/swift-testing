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
#if canImport(Combine)
public import Combine
#endif

@_spi(Experimental)
extension Attachment {
  public init<T>(
    encoding encodableValue: T,
    as encodingFormat: EncodingFormat? = nil,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where AttachableValue == _AttachableEncodableWrapper<T, Void> {
    let encodingFormat: EncodingFormat = if let encodingFormat {
      encodingFormat
    } else if let encodingFormat = try preferredName.flatMap(EncodingFormat.init(forPreferredName:)) {
      encodingFormat
    } else {
      // The developer did not specify, so default to JSON.
      .json
    }
    let wrapper = _AttachableEncodableWrapper(encoding: encodableValue, as: encodingFormat)
    self.init(wrapper, named: preferredName, sourceLocation: sourceLocation)
  }

  public init<T>(
    encoding encodableValue: T,
    as propertyListFormat: PropertyListSerialization.PropertyListFormat,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where AttachableValue == _AttachableEncodableWrapper<T, Void> {
    try self.init(
      encoding: encodableValue,
      as: .propertyListFormat(propertyListFormat),
      named: preferredName,
      sourceLocation: sourceLocation
    )
  }

#if canImport(Combine)
  public init<T, E>(
    encoding encodableValue: T,
    using encoder: E,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where AttachableValue == _AttachableEncodableWrapper<T, E>, E: TopLevelEncoder, E.Output: ContiguousBytes {
    let wrapper = _AttachableEncodableWrapper(encoding: encodableValue, using: encoder)
    self.init(wrapper, named: preferredName, sourceLocation: sourceLocation)
  }
#endif
}
#endif
