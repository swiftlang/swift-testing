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

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
private import UniformTypeIdentifiers
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

// MARK: - Attaching files

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
@available(_uttypesAPI, *)
extension UTType {
  /// A type that represents a `.tgz` archive, or `nil` if the system does not
  /// recognize that content type.
  fileprivate static let tgz = UTType("org.gnu.gnu-zip-tar-archive")
}
#endif

@_spi(Experimental)
extension Test.Attachment {
  /// Initialize an instance of this type with the contents of the given URL.
  ///
  /// - Parameters:
  ///   - url: The URL containing the attachment's data.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the name of the attachment is
  ///     derived from the last path component of `url`.
  ///   - sourceLocation: The source location of the attachment.
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

    // FIXME: use NSFileCoordinator on Darwin?

    let url = url.resolvingSymlinksInPath()
    let isDirectory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory!

    // Determine the preferred name of the attachment if one was not provided.
    var preferredName = if let preferredName {
      preferredName
    } else if case let lastPathComponent = url.lastPathComponent, !lastPathComponent.isEmpty {
      lastPathComponent
    } else {
      Self.defaultPreferredName
    }

    if isDirectory {
      // Ensure the preferred name of the archive has an appropriate extension.
      preferredName = {
#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
        if #available(_uttypesAPI, *), let tgz = UTType.tgz {
          return (preferredName as NSString).appendingPathExtension(for: tgz)
        }
#endif
        return (preferredName as NSString).appendingPathExtension("tgz") ?? preferredName
      }()

      let attachableValue = try await _DirectoryContentAttachableProxy(contentsOfDirectoryAt: url)
      self.init(attachableValue, named: preferredName, sourceLocation: sourceLocation)
    } else {
      // Load the file.
      let attachableValue = try Data(contentsOf: url, options: [.mappedIfSafe])
      self.init(attachableValue, named: preferredName, sourceLocation: sourceLocation)
    }
  }
}

// MARK: - Attaching directories

/// A type representing the content of a directory as an attachable value.
private struct _DirectoryContentAttachableProxy: Test.Attachable {
  /// The URL of the directory.
  ///
  /// The contents of this directory may change after this instance is
  /// initialized. Such changes are not tracked.
  var url: URL

  /// The archived contents of the directory.
  private let _directoryContent: Data

  /// Initialize an instance of this type.
  ///
  /// - Parameters:
  ///   - directoryURL: A URL referring to the directory to attach.
  ///
  /// - Throws: Any error encountered trying to compress the directory, or if
  ///   directories cannot be compressed on this platform.
  ///
  /// This initializer asynchronously compresses the contents of `directoryURL`
  /// into an archive (currently of `.tgz` format, although this is subject to
  /// change) and stores a mapped copy of that archive.
  init(contentsOfDirectoryAt directoryURL: URL) async throws {
    url = directoryURL

    let temporaryName = "\(UUID().uuidString).tgz"
    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(temporaryName)

#if !SWT_NO_PROCESS_SPAWNING
#if os(Windows)
    let tarPath = #"C:\Windows\System32\tar.exe"#
#else
    let tarPath = "/usr/bin/tar"
#endif
    let sourcePath = url.fileSystemPath
    let destinationPath = temporaryURL.fileSystemPath
    defer {
      remove(destinationPath)
    }

    try await withCheckedThrowingContinuation { continuation in
      do {
        _ = try Process.run(
          URL(fileURLWithPath: tarPath, isDirectory: false),
          arguments: ["--create", "--gzip", "--directory", sourcePath, "--file", destinationPath, "."]
        ) { process in
          let terminationReason = process.terminationReason
          let terminationStatus = process.terminationStatus
          if terminationReason == .exit && terminationStatus == EXIT_SUCCESS {
            continuation.resume()
          } else {
            let error = CocoaError(.fileWriteUnknown, userInfo: [
              NSLocalizedDescriptionKey: "The directory at '\(sourcePath)' could not be compressed.",
            ])
            continuation.resume(throwing: error)
          }
        }
      } catch {
        continuation.resume(throwing: error)
      }
    }
    _directoryContent = try Data(contentsOf: temporaryURL, options: [.mappedIfSafe])
#else
    throw CocoaError(.featureUnsupported, userInfo: [NSLocalizedDescriptionKey: "This platform does not support attaching directories to tests."])
#endif
  }

  func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try _directoryContent.withUnsafeBytes(body)
  }
}
#endif
#endif
