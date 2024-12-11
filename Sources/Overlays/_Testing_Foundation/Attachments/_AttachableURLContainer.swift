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

/// A wrapper type representing file system objects and URLs that can be
/// attached indirectly.
///
/// You do not need to use this type directly. Instead, initialize an instance
/// of ``Attachment`` using a file URL.
@_spi(Experimental)
public struct _AttachableURLContainer: Sendable {
  /// The underlying URL.
  var url: URL

  /// The data contained at ``url``.
  var data: Data

  /// Whether or not this instance represents a compressed directory.
  var isCompressedDirectory: Bool
}

// MARK: -

extension _AttachableURLContainer: AttachableContainer {
  public var attachableValue: URL {
    url
  }

  public func withUnsafeBufferPointer<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try data.withUnsafeBytes(body)
  }

  public borrowing func preferredName(for attachment: borrowing Attachment<Self>, basedOn suggestedName: String) -> String {
    // Reconstruct this instance's URL with the suggested name. This is done as
    // a convenience so that we can use URL's API for manipulating paths. We
    // could also do this by repeatedly casting to NSString, but that code is
    // harder to read.
    var url = url
    url.deleteLastPathComponent()
    url.appendPathComponent(suggestedName, isDirectory: false)

    // Ensure the path extension on the URL matches the original file's (or in
    // the case of a compressed directory, is ".zip".)
    let suggestedPathExtension = if isCompressedDirectory {
      "zip"
    } else {
      (suggestedName as NSString).pathExtension
    }
    let urlPathExtension = url.pathExtension
    if !suggestedPathExtension.isEmpty, suggestedPathExtension.caseInsensitiveCompare(urlPathExtension) != .orderedSame {
      url.appendPathExtension(suggestedPathExtension)
    }

    return url.lastPathComponent
  }
}
#endif
