//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftSyntax
import SwiftSyntaxBuilder

// FIXME: Instead of depending on Foundation, adopt API provided by SwiftPM in rdar://111523616
// Note that SwiftPM already depends on Foundation, and this dependency does not
// introduce a dependency in the testing library, only in this helper tool.
import Foundation

// Resolve arguments to the tool.
let repoPath = CommandLine.arguments[1]
let generatedSourceURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: false)

/// Run the `git` tool and process the output it writes to standard output.
///
/// - Parameters:
///   - arguments: The arguments to pass to `git`.
///   - maxOutputCount: The maximum amount of output to read and return.
///
/// - Returns: A string containing the `git` command's output, up to
///   `maxOutputCount` UTF-8-encoded bytes, or `nil` if the command failed or
///   the output could not be read.
func _runGit(passing arguments: String..., readingUpToCount maxOutputCount: Int) -> String? {
#if os(macOS) || os(Linux) || os(Windows)
  let path: String
  var arguments = ["-C", repoPath] + arguments
#if os(Windows)
  path = "C:\\Program Files\\Git\\cmd\\git.exe"
#else
  path = "/usr/bin/env"
  arguments = CollectionOfOne("git") + arguments
#endif

  let process = Process()
  process.executableURL = URL(fileURLWithPath: path, isDirectory: false)
  process.arguments = arguments

  let stdoutPipe = Pipe()
  process.standardOutput = stdoutPipe
  process.standardError = nil
  do {
    try process.run()
  } catch {
    return nil
  }
  defer {
    process.terminate()
  }
  guard let output = try? stdoutPipe.fileHandleForReading.read(upToCount: maxOutputCount) else {
    return nil
  }
  return String(data: output, encoding: .utf8)
#else
  return nil
#endif
}

// The current Git tag, if available.
let currentGitTag = _runGit(passing: "describe", "--exact-match", "--tags", readingUpToCount: 40)?
  .split(whereSeparator: \.isNewline)
  .first
  .map(String.init)

// The current Git commit hash, if available.
let currentGitCommitHash = _runGit(passing: "rev-parse", "HEAD", readingUpToCount: 40)?
  .split(whereSeparator: \.isNewline)
  .first
  .map(String.init)

// Whether or not the Git repository has uncommitted changes, if available.
let gitHasUncommittedChanges = _runGit(passing: "status", "-s", readingUpToCount: 1)
  .map { !$0.isEmpty } ?? false

// Figure out what value to emit for the testing library version. If the
// repository is sitting at a tag with no uncommitted changes, use the tag.
// Otherwise, use the commit hash (with a "there are changes" marker if needed.)
// Finally, fall back to nil if nothing else is available.
let sourceCode: DeclSyntax = if !gitHasUncommittedChanges, let currentGitTag {
  """
  var _testingLibraryVersion: String? {
    \(literal: currentGitTag)
  }
  """
} else if let currentGitCommitHash {
  if gitHasUncommittedChanges {
    """
    var _testingLibraryVersion: String? {
      \(literal: currentGitCommitHash) + " (modified)"
    }
    """
  } else {
    """
    var _testingLibraryVersion: String? {
      \(literal: currentGitCommitHash)
    }
    """
  }
} else {
  """
  var _testingLibraryVersion: String? {
    nil
  }
  """
}

// Write the generated Swift file to the specified destination path.
try String(describing: sourceCode).write(to: generatedSourceURL, atomically: false, encoding: .utf8)
