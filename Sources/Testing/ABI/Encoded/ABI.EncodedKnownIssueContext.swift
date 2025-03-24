//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABI {
  /// A type implementing the JSON encoding of
  /// ``Issue/KnownIssueContext-swift.struct`` for the ABI entry point and
  /// event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  ///
  /// - Warning: Known issues are not yet part of the JSON schema.
  struct EncodedKnownIssueContext<V>: Sendable where V: ABI.Version {
    /// The comment that was passed to `withKnownIssue()`, if any.
    var comment: Comment?

    /// The source location that was passed to `withKnownIssue()`.
    var sourceLocation: SourceLocation

    init(encoding context: Issue.KnownIssueContext, in eventContext: borrowing Event.Context) {
      comment = context.comment
      sourceLocation = context.sourceLocation
    }
  }
}

// MARK: - Codable

extension ABI.EncodedKnownIssueContext: Codable {}
