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

/// A wrapper type representing file system objects and URLs that can be
/// attached indirectly.
///
/// You do not need to use this type directly. Instead, initialize an instance
/// of ``Attachment`` using a file URL.
public struct _AttachableURLWrapper: Sendable {
  /// The underlying URL.
  var url: URL

  /// The data contained at ``url``.
  var data: Data

  /// Whether or not this instance represents a compressed directory.
  var isCompressedDirectory: Bool
}

// MARK: -

extension _AttachableURLWrapper: AttachableWrapper {
  public var wrappedValue: URL {
    url
  }

  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try data.withUnsafeBytes(body)
  }

  public borrowing func _write(toFileAtPath filePath: String, for attachment: borrowing Attachment<Self>) throws {
    func throwEEXISTIfNeeded() throws {
      if errno == POSIXError.EEXIST.rawValue {
        throw POSIXError(.EEXIST)
      }
    }

#if SWT_TARGET_OS_APPLE && !SWT_NO_CLONEFILE
    let cloned = try url.withUnsafeFileSystemRepresentation { sourcePath in
      try filePath.withCString { destinationPath in
        guard let sourcePath else {
          return false
        }

        // Attempt to clone the source file.
        guard 0 == clonefile(sourcePath, destinationPath, 0) else {
          try throwEEXISTIfNeeded()
          return false
        }
        return true
      }
    }
#elseif os(Linux) && !SWT_NO_FICLONE
    let cloned = try url.withUnsafeFileSystemRepresentation { sourcePath in
      try filePath.withCString { destinationPath in
        guard let sourcePath else {
          return false
        }

        // Open the source and destination file descriptors.
        let srcFD = open(sourcePath, O_RDONLY)
        guard srcFD >= 0 else {
          return false
        }
        defer {
          close(srcFD)
        }
        let dstFD = open(destinationPath, O_CREAT | O_EXCL, mode_t(0o666))
        guard dstFD >= 0 else {
          try throwEEXISTIfNeeded()
          return false
        }
        defer {
          close(dstFD)
        }

        // Attempt to clone the source file.
        if -1 == ioctl(dstFD, FICLONE, srcFD) {
          try throwEEXISTIfNeeded()
          return false
        }
        return true
      }
    }
#else
    let cloned = false
#endif
    guard Bool(cloned) else {
      // Fall back to a byte-by-byte copy.
      return try writeImpl(toFileAtPath: filePath, for: attachment)
    }
  }

  public borrowing func preferredName(for attachment: borrowing Attachment<Self>, basedOn suggestedName: String) -> String {
    // What extension should we have on the filename so that it has the same
    // type as the original file (or, in the case of a compressed directory, is
    // a zip file?)
    let preferredPathExtension = if isCompressedDirectory {
      "zip"
    } else {
      url.pathExtension
    }

    // What path extension is on the suggested name already?
    let nsSuggestedName = suggestedName as NSString
    let suggestedPathExtension = nsSuggestedName.pathExtension

    // If the suggested name's extension isn't what we would prefer, append the
    // preferred extension.
    if !preferredPathExtension.isEmpty,
       suggestedPathExtension.caseInsensitiveCompare(preferredPathExtension) != .orderedSame,
       let result = nsSuggestedName.appendingPathExtension(preferredPathExtension) {
      return result
    }

    return suggestedName
  }
}
#endif
