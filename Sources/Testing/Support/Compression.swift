//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

#if !SWT_NO_FILE_IO && !SWT_NO_PROCESS_SPAWNING
/// An enumeration describing errors that may occur when calling
/// ``compressFileSystemObject(atPath:toPath:)``.
private enum _CompressionError: Error {
  /// The external compression tool failed.
  ///
  /// - Parameters:
  ///   - exitCondition: The exit condition of the external compression tool.
  case compressionProcessFailed(_ exitCondition: ExitCondition)
}

/// Compress a file system object.
///
/// - Parameters:
///   - sourcePath: The path to the existing (uncompressed) file system object.
///   - destinationPath: The path to which the compressed archive should be
///     written.
///
/// - Throws: Any error that caused compression to fail.
///
/// This function generates `.tar.gz` archives on all platforms that support
/// spawning child processes. On platforms that do not support process spawning,
/// this function always fails.
///
/// This function is used by the testing library's Foundation cross-import
/// overlay. It is implemented here so that we can reuse `spawnExecutable()`,
/// `ExitCondition`, etc.
package func compressFileSystemObject(atPath sourcePath: String, toPath destinationPath: String) async throws {
#if os(Windows)
  let tarPath = #"C:\Windows\System32\tar.exe"#
#else
  let tarPath = "/usr/bin/tar"
#endif

  let processID = try spawnExecutable(
    atPath: tarPath,
    arguments: ["--create", "--gzip", "--file", destinationPath, sourcePath],
    environment: [:]
  )
  let exitCondition = try await wait(for: processID)
  if exitCondition != .success {
    throw _CompressionError.compressionProcessFailed(exitCondition)
  }
}
#endif
