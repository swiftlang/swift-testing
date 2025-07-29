//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if os(Windows)
@_spi(Experimental) public import Testing

@_spi(Experimental)
@available(_uttypesAPI, *)
extension Attachment {
  public init<T>(
    _ attachableValue: T,
    named preferredName: String? = nil,
    as imageFormat: AttachableImageFormat? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) where AttachableValue == _AttachableImageWrapper<T> {
    let imageWrapper = _AttachableImageWrapper(image: attachableValue, imageFormat: imageFormat)
    self.init(imageWrapper, named: preferredName, sourceLocation: sourceLocation)
  }

  public static func record<T>(
    _ image: consuming T,
    named preferredName: String? = nil,
    as imageFormat: AttachableImageFormat? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) where AttachableValue == _AttachableImageWrapper<T> {
    let attachment = Self(image, named: preferredName, as: imageFormat, sourceLocation: sourceLocation)
    Self.record(attachment, sourceLocation: sourceLocation)
  }
}
#endif
