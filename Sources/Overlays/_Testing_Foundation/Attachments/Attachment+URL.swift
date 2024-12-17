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
@_spi(Experimental) @_spi(ForSwiftTestingOnly) public import Testing
public import Foundation

#if !SWT_NO_PROCESS_SPAWNING && os(Windows)
private import WinSDK
#endif

#if !SWT_NO_FILE_IO
extension URL {
  /// The file system path of the URL, equivalent to `path`.
  var fileSystemPath: String {
#if os(Windows)
    // BUG: `path` includes a leading slash which makes it invalid on Windows.
    // SEE: https://github.com/swiftlang/swift-foundation/pull/964
    let path = path
    if path.starts(with: /\/[A-Za-z]:\//) {
      return String(path.dropFirst())
    }
#endif
    return path
  }
}

@_spi(Experimental)
extension Attachment where AttachableValue == _AttachableURLContainer {
#if SWT_TARGET_OS_APPLE
  /// An operation queue to use for asynchronously reading data from disk.
  private static let _operationQueue = OperationQueue()
#endif

  /// Initialize an instance of this type with the contents of the given URL.
  ///
  /// - Parameters:
  ///   - url: The URL containing the attachment's data.
  ///   - preferredName: The preferred name of the attachment when writing it to
  ///     a test report or to disk. If `nil`, the name of the attachment is
  ///     derived from the last path component of `url`.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// - Throws: Any error that occurs attempting to read from `url`.
  public init(
    contentsOf url: URL,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws {
    guard url.isFileURL else {
      // TODO: network URLs?
      throw CocoaError(.featureUnsupported, userInfo: [NSLocalizedDescriptionKey: "Attaching downloaded files is not supported"])
    }

    // If the user did not provide a preferred name, derive it from the URL.
    let preferredName = preferredName ?? url.lastPathComponent

    let url = url.resolvingSymlinksInPath()
    let isDirectory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory!

#if SWT_TARGET_OS_APPLE
    let data: Data = try await withCheckedThrowingContinuation { continuation in
      let fileCoordinator = NSFileCoordinator()
      let fileAccessIntent = NSFileAccessIntent.readingIntent(with: url, options: [.forUploading])

      fileCoordinator.coordinate(with: [fileAccessIntent], queue: Self._operationQueue) { error in
        let result = Result {
          if let error {
            throw error
          }
          return try Data(contentsOf: fileAccessIntent.url, options: [.mappedIfSafe])
        }
        continuation.resume(with: result)
      }
    }
#else
    let data = if isDirectory {
      try await _compressContentsOfDirectory(at: url)
    } else {
      // Load the file.
      try Data(contentsOf: url, options: [.mappedIfSafe])
    }
#endif

    let urlContainer = _AttachableURLContainer(url: url, data: data, isCompressedDirectory: isDirectory)
    self.init(urlContainer, named: preferredName, sourceLocation: sourceLocation)
  }
}

#if !SWT_NO_PROCESS_SPAWNING && os(Windows)
/// The filename of the archiver tool.
private let _archiverName = "tar.exe"

/// The path to the archiver tool.
///
/// This path refers to a file (named `_archiverName`) within the `"System32"`
/// folder of the current system, which is not always located in `"C:\Windows."`
///
/// If the path cannot be determined, the value of this property is `nil`.
private let _archiverPath: String? = {
  let bufferCount = GetSystemDirectoryW(nil, 0)
  guard bufferCount > 0 else {
    return nil
  }

  return withUnsafeTemporaryAllocation(of: wchar_t.self, capacity: Int(bufferCount)) { buffer -> String? in
    let bufferCount = GetSystemDirectoryW(buffer.baseAddress!, UINT(buffer.count))
    guard bufferCount > 0 && bufferCount < buffer.count else {
      return nil
    }

    return _archiverName.withCString(encodedAs: UTF16.self) { archiverName -> String? in
      var result: UnsafeMutablePointer<wchar_t>?

      let flags = ULONG(PATHCCH_ALLOW_LONG_PATHS.rawValue)
      guard S_OK == PathAllocCombine(buffer.baseAddress!, archiverName, flags, &result) else {
        return nil
      }
      defer {
        LocalFree(result)
      }

      return result.flatMap { String.decodeCString($0, as: UTF16.self)?.result }
    }
  }
}()
#endif

/// Compress the contents of a directory to an archive, then map that archive
/// back into memory.
///
/// - Parameters:
///   - directoryURL: A URL referring to the directory to attach.
///
/// - Returns: An instance of `Data` containing the compressed contents of the
///   given directory.
///
/// - Throws: Any error encountered trying to compress the directory, or if
///   directories cannot be compressed on this platform.
///
/// This function asynchronously compresses the contents of `directoryURL` into
/// an archive (currently of `.zip` format, although this is subject to change.)
private func _compressContentsOfDirectory(at directoryURL: URL) async throws -> Data {
#if !SWT_NO_PROCESS_SPAWNING
  let temporaryName = "\(UUID().uuidString).zip"
  let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(temporaryName)
  defer {
    try? FileManager().removeItem(at: temporaryURL)
  }

  // The standard version of tar(1) does not (appear to) support writing PKZIP
  // archives. FreeBSD's (AKA bsdtar) was long ago rebased atop libarchive and
  // knows how to write PKZIP archives, while Windows inherited FreeBSD's tar
  // tool in Windows 10 Build 17063 (per https://techcommunity.microsoft.com/blog/containers/tar-and-curl-come-to-windows/382409).
  //
  // On Linux (which does not have FreeBSD's version of tar(1)), we can use
  // zip(1) instead.
#if os(Linux)
  let archiverPath = "/usr/bin/zip"
#elseif SWT_TARGET_OS_APPLE || os(FreeBSD)
  let archiverPath = "/usr/bin/tar"
#elseif os(Windows)
  guard let archiverPath = _archiverPath else {
    throw CocoaError(.fileWriteUnknown, userInfo: [
      NSLocalizedDescriptionKey: "Could not determine the path to '\(_archiverName)'.",
    ])
  }
#else
#warning("Platform-specific implementation missing: tar or zip tool unavailable")
  let archiverPath = ""
  throw CocoaError(.featureUnsupported, userInfo: [NSLocalizedDescriptionKey: "This platform does not support attaching directories to tests."])
#endif

  try await withCheckedThrowingContinuation { continuation in
    let process = Process()

    process.executableURL = URL(fileURLWithPath: archiverPath, isDirectory: false)

    let sourcePath = directoryURL.fileSystemPath
    let destinationPath = temporaryURL.fileSystemPath
#if os(Linux)
    // The zip command constructs relative paths from the current working
    // directory rather than from command-line arguments.
    process.arguments = [destinationPath, "--recurse-paths", "."]
    process.currentDirectoryURL = directoryURL
#elseif SWT_TARGET_OS_APPLE || os(FreeBSD)
    process.arguments = ["--create", "--auto-compress", "--directory", sourcePath, "--file", destinationPath, "."]
#elseif os(Windows)
    // The Windows version of bsdtar can handle relative paths for other archive
    // formats, but produces empty archives when inferring the zip format with
    // --auto-compress, so archive with absolute paths here.
    //
    // An alternative may be to use PowerShell's Compress-Archive command,
    // however that comes with a security risk as we'd be responsible for two
    // levels of command-line argument escaping.
    process.arguments = ["--create", "--auto-compress", "--file", destinationPath, sourcePath]
#endif

    process.standardOutput = nil
    process.standardError = nil

    process.terminationHandler = { process in
      let terminationReason = process.terminationReason
      let terminationStatus = process.terminationStatus
      if terminationReason == .exit && terminationStatus == EXIT_SUCCESS {
        continuation.resume()
      } else {
        let error = CocoaError(.fileWriteUnknown, userInfo: [
          NSLocalizedDescriptionKey: "The directory at '\(sourcePath)' could not be compressed (\(terminationStatus)).",
        ])
        continuation.resume(throwing: error)
      }
    }

    do {
      try process.run()
    } catch {
      continuation.resume(throwing: error)
    }
  }

  return try Data(contentsOf: temporaryURL, options: [.mappedIfSafe])
#else
  throw CocoaError(.featureUnsupported, userInfo: [NSLocalizedDescriptionKey: "This platform does not support attaching directories to tests."])
#endif
}
#endif
#endif
