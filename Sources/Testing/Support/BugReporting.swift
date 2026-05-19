//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A standardized message inviting a user to file a bug report at the provided
/// URL.
package var fileABugMessage: String {
  _fileABugMessage(context: "")
}

/// A standardized message inviting a user to file a bug report at the provided
/// URL and include the specified contextual information.
///
/// - Parameters:
///   - context: Additional diagnostic information to include with the bug
///     report message.
///
/// - Returns: A string combining a standard request to file a bug report (with
///   a URL provided) and `context`.
package func fileABugMessage(context: String) -> String {
  _fileABugMessage(context: context)
}

/// Construct a message inviting a user to file a bug report with some optional
/// context to provide.
///
/// - Parameters:
///   - context: Optional additional diagnostic information to include with the
///     bug report message.
///
/// - Returns: A string combining a standard request to file a bug report (with
///   a URL provided) and `context`, if provided.
///
/// This common implementation function is provided because calling
/// `fileABugMessage(context:)` directly from the `fileABugMessage` property
/// getter isn't supported since they have the same base name.
private func _fileABugMessage(context: String?) -> String {
  var result = "Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new"
  if let context {
    result += " and include this information: \(context)"
  }
  return result
}
