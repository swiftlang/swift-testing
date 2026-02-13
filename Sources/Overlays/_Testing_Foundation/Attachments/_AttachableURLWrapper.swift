//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation) && !SWT_NO_FILE_IO
public import Testing
public import Foundation

#if !SWT_NO_FILE_CLONING
private import _TestingInternals.StubsOnly
#endif

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

#if !SWT_NO_FILE_CLONING && !os(Windows)
  /// A file handle that refers to the original file (or, if a directory, the
  /// compressed copy thereof).
  ///
  /// This file handle is used when cloning the represented file. If the value
  /// of this property is `nil`, cloning won't be available for said file.
  private var _fileHandle: FileHandle?
#endif

  /// Initialize an instance of this type representing a given URL.
  ///
  /// - Parameters:
  ///   - url: The original URL being used as an attachable value.
  ///   - copyURL: Optionally, a URL to which `url` was copied.
  ///   - isCompressedDirectory: Whether or not the file system object at `url`
  ///     is a directory (if so, `copyURL` must refer to its compressed copy.)
  ///
  /// - Throws: Any error that occurs trying to open `url` or `copyURL` for
  ///   mapping. On platforms that support file cloning, an error may also be
  ///   thrown if a file descriptor to `url` or `copyURL` cannot be created.
  init(url: URL, copiedToFileAt copyURL: URL? = nil, isCompressedDirectory: Bool) throws {
    if isCompressedDirectory && copyURL == nil {
      preconditionFailure("When attaching a directory to a test, the URL to its compressed copy must be supplied. Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    }
    self.url = url
    self.data = try Data(contentsOf: copyURL ?? url, options: [.mappedIfSafe])
    self.isCompressedDirectory = isCompressedDirectory
#if !SWT_NO_FILE_CLONING && !os(Windows)
    self._fileHandle = (copyURL ?? url).withUnsafeFileSystemRepresentation { path in
      guard let path else {
        return nil
      }
      let fd = open(path, O_RDONLY | O_CLOEXEC)
      guard fd >= 0 else {
        return nil
      }
      return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }
#endif
  }
}

// MARK: -

extension _AttachableURLWrapper: AttachableWrapper {
  public var wrappedValue: URL {
    url
  }

  public var estimatedAttachmentByteCount: Int? {
    data.count
  }

  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try data.withUnsafeBytes(body)
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

#if !SWT_NO_FILE_CLONING
extension _AttachableURLWrapper: FileClonable {
  public borrowing func clone(toFileAtPath filePath: String) -> Bool {
#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD)
    guard let srcFD = _fileHandle?.fileDescriptor else {
      return false
    }
#endif
#if SWT_TARGET_OS_APPLE
    return 0 == fclonefileat(srcFD, AT_FDCWD, filePath, 0)
#elseif os(Linux) || os(FreeBSD)
    // Open the destination file for exclusive writing.
    let dstFD = open(filePath, O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, mode_t(0o666))
    guard dstFD >= 0 else {
      return false
    }
    defer {
      close(dstFD)
    }
#if os(Linux)
    return -1 != ioctl(dstFD, swt_FICLONE(), srcFD)
#elseif os(FreeBSD)
    var flags = CUnsignedInt(0)
    if Self._freeBSDVersion >= 1500000 {
      // `COPY_FILE_RANGE_CLONE` was introduced in FreeBSD 15.0, but on 14.3
      // we can still benefit from an in-kernel copy instead.
      flags |= swt_COPY_FILE_RANGE_CLONE()
    }
    return -1 != copy_file_range(srcFD, nil, dstFD, nil, Int(SSIZE_MAX), flags)
#endif
#elseif os(Windows)
    // TODO: Windows implementation
    // Block cloning on Windows is only supported by ReFS which is not in
    // wide use at this time. SEE: https://learn.microsoft.com/en-us/windows/win32/fileio/block-cloning
    return false
#else
#warning("Platform-specific implementation missing: File cloning unavailable")
    return false
#endif
  }
}
#endif
#endif
