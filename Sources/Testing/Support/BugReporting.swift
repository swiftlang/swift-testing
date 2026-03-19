//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// Construct a message describing a problem and inviting a user to file a bug
/// report.
///
/// - Parameters:
///   - message: A description of the problem encountered.
///   - context: Optional additional diagnostic information to include with the
///     bug report request.
///
/// - Returns: A string combining `message` with a standard request to file a
///   bug report (with a URL provided), optionally followed by `context`.
///
/// This function is not part of the public interface of the testing library.
package func reportBugMessage(_ message: String, context: String? = nil) -> String {
  var result = "\(message) Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new"
  if let context {
    result += " and include this information: \(context)"
  }
  return result
}
