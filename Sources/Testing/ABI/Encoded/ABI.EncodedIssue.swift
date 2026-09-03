//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_ABI_JSON_SCHEMA
extension ABI {
  /// A type implementing the JSON encoding of ``Issue`` for the ABI entry point
  /// and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedIssue<V>: Sendable where V: ABI.Version {
    /// An enumeration representing the level of severity of a recorded issue.
    ///
    /// For descriptions of individual cases, see ``Issue/Severity-swift.enum``.
    enum Severity: String, Sendable {
      case warning
      case error
    }

    /// The severity of this issue.
    ///
    /// Prior to 6.3, this is nil.
    ///
    /// @Metadata {
    ///   @Available(Swift, introduced: 6.3)
    ///   @Available(Xcode, introduced: 26.4)
    /// }
    var severity: Severity?

    /// If the issue is a failing issue.
    ///
    /// Prior to 6.3, this is nil.
    ///
    /// @Metadata {
    ///   @Available(Swift, introduced: 6.3)
    ///   @Available(Xcode, introduced: 26.4)
    /// }
    var isFailure: Bool?

    /// Whether or not this issue is known to occur.
    var isKnown: Bool

    /// A comment associated with the known issue, if any.
    ///
    /// If not nil, this is encoded as the value for `isKnown` field in the
    /// JSON schema.
    var knownIssueComment: String?

    /// The location in source where this issue occurred, if available.
    ///
    /// TODO: how to handle this no longer being available in v6.5?
    public var sourceLocation: EncodedSourceLocation<V>?

    /// The backtrace where this issue occurred, if available.
    ///
    /// - Warning: Backtraces are not yet part of the JSON schema.
    var _backtrace: EncodedBacktrace<V>?

    /// The error associated with this issue, if applicable.
    var error: EncodedError<V>?

    /// The expression associated with this issue, if applicable.
    var expression: EncodedExpression<V>?

    /// The actual and expected confirmation counts associated with this issue,
    /// if applicable.
    var confirmationMiscount: EncodedConfirmationMiscount<V>?

    /// The exceeded time limit associated with this issue, if applicable.
    var exceededTimeLimit: Double?

    init(encoding issue: borrowing Issue, in eventContext: borrowing Event.Context) {
      // >= v0
      isKnown = issue.isKnown
      sourceLocation = issue.sourceLocation.map { EncodedSourceLocation(encoding: $0) }

      // >= v6.3
      if V.versionNumber >= ABI.v6_3.versionNumber {
        severity = switch issue.severity {
        case .warning: .warning
        case .error: .error
        }
        isFailure = issue.isFailure
      }

      // >= v6.5
      if V.versionNumber >= ABI.v6_5.versionNumber {
        // SourceLocation is encoded in the parent Event structure instead
        sourceLocation = nil
        if case .expectationFailed(let expectation) = issue.kind {
          expression = EncodedExpression(encoding: expectation.evaluatedExpression)
        }

        if case .timeLimitExceeded(let components) = issue.kind {
          exceededTimeLimit = Double(components.seconds)
        }

        if let knownIssueContext = issue.knownIssueContext {
          knownIssueComment = knownIssueContext.comment?.rawValue
        }

        if case .confirmationMiscounted(let actual, let expected) = issue.kind {
          confirmationMiscount = EncodedConfirmationMiscount(encoding: (actual: actual, expected: expected))
        }

        error = if let error = issue.error {
          EncodedError(encoding: error)
        } else {
          switch issue.kind {
          case .apiMisused:
            EncodedError(encoding: APIMisuseError(description: ""))
          case .system:
            EncodedError(encoding: SystemError(description: ""))
          case .knownIssueNotRecorded:
            EncodedError(encoding: KnownIssueNotRecordedError(description: ""))
          default:
            nil
          }
        }
      }

      // Experimental fields
      if V.includesExperimentalFields {
        if let backtrace = issue.sourceContext.backtrace {
          _backtrace = EncodedBacktrace(encoding: backtrace, in: eventContext)
        }
      }
    }
  }
}

// MARK: - Codable

extension ABI.EncodedIssue: Codable {
  private enum _CodingKeys: String, CodingKey {
    case severity
    case isFailure
    case isKnown
    case sourceLocation
    case _backtrace
    case error
    case expression
    case exceededTimeLimit
    case confirmationMiscount
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: _CodingKeys.self)

    try container.encodeIfPresent(severity, forKey: .severity)
    try container.encodeIfPresent(isFailure, forKey: .isFailure)

    // >= 6.5: isKnown is an optional field. Use knownIssueComment if present.
    //         Omit the field if isKnown is false.
    // <  6.5: isKnown is a required boolean field
    if V.versionNumber >= ABI.v6_5.versionNumber {
      if let knownIssueComment {
        try container.encode(knownIssueComment, forKey: .isKnown)
      } else if isKnown {
        try container.encode(isKnown, forKey: .isKnown)
      }
    } else {
      try container.encode(isKnown, forKey: .isKnown)
    }
    try container.encodeIfPresent(sourceLocation, forKey: .sourceLocation)
    try container.encodeIfPresent(_backtrace, forKey: ._backtrace)
    try container.encodeIfPresent(error, forKey: .error)
    try container.encodeIfPresent(expression, forKey: .expression)
    try container.encodeIfPresent(exceededTimeLimit, forKey: .exceededTimeLimit)
    try container.encodeIfPresent(confirmationMiscount, forKey: .confirmationMiscount)
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: _CodingKeys.self)

    severity = try container.decodeIfPresent(Severity.self, forKey: .severity)
    isFailure = try container.decodeIfPresent(Bool.self, forKey: .isFailure)

    // >= 6.5: isKnown is an optional field, and resolves to false if missing.
    // <  6.5: isKnown is always present as a boolean
    if V.versionNumber >= ABI.v6_5.versionNumber {
      if let knownIssueComment = try? container.decodeIfPresent(String.self, forKey: .isKnown) {
        isKnown = true
        self.knownIssueComment = knownIssueComment
      } else {
        isKnown = try container.decodeIfPresent(Bool.self, forKey: .isKnown) ?? false
      }
    } else {
      isKnown = try container.decode(Bool.self, forKey: .isKnown)
    }

    sourceLocation = try container.decodeIfPresent(
      ABI.EncodedSourceLocation<V>.self, forKey: .sourceLocation)
    _backtrace = try container.decodeIfPresent(ABI.EncodedBacktrace<V>.self, forKey: ._backtrace)
    error = try container.decodeIfPresent(ABI.EncodedError<V>.self, forKey: .error)
    expression = try container.decodeIfPresent(ABI.EncodedExpression<V>.self, forKey: .expression)
    exceededTimeLimit = try container.decodeIfPresent(Double.self, forKey: .exceededTimeLimit)
    confirmationMiscount = try container.decodeIfPresent(
      ABI.EncodedConfirmationMiscount<V>.self, forKey: .confirmationMiscount)
  }
}
extension ABI.EncodedIssue.Severity: Codable {}

// MARK: - Conversion to/from library types

extension Issue {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - event: The encoded event to initialize this instance from.
  ///
  /// If `event` does not represent a recorded issue, the initializer returns
  /// `nil`.
  init?<V>(decoding event: ABI.EncodedEvent<V>) {
    guard let issue = event.issue else {
      return nil
    }
    self.init(decoding: issue, sourceLocation: event.sourceLocation)
    if let comments = event.comments {
      self.comments += comments.map(Comment.init(rawValue:))
    }
  }

  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - issue: The encoded issue to initialize this instance from.
  ///   - sourceLocation: The source location associated with the issue.
  ///   If the encoded issue has a non-nil source location, this takes
  ///   precedence. Required for >=v6.5, where sourceLocation is no longer
  ///   available as part of the encoded issue.
  ///
  /// - Note: For higher fidelity, initialize the issue with an encoded event
  ///   representing a recorded issue rather than just the encoded issue.
  init?<V>(decoding issue: ABI.EncodedIssue<V>, sourceLocation: ABI.EncodedSourceLocation<V>? = nil) {
    let sourceLocation = sourceLocation ?? issue.sourceLocation
    let issueKind: Issue.Kind
    if let error = issue.error {
      switch error.domain {
      case APIMisuseError.domain:
        issueKind = .apiMisused
      case SystemError.domain:
        issueKind = .system
      case KnownIssueNotRecordedError.domain:
        issueKind = .knownIssueNotRecorded
      default:
        issueKind = .errorCaught(error)
      }
    } else if let expression = issue.expression.flatMap(__Expression.init(decoding:)),
      let sourceLocation = sourceLocation.flatMap(SourceLocation.init)
    {
      let expectation = Expectation(
        evaluatedExpression: expression,
        isPassing: false,
        isRequired: false,
        sourceLocation: sourceLocation
      )
      issueKind = .expectationFailed(expectation)
    } else if let exceededTimeLimit = issue.exceededTimeLimit {
      let duration = Duration.seconds(exceededTimeLimit)
      issueKind = .timeLimitExceeded(timeLimitComponents: duration.components)
    } else if let miscount = issue.confirmationMiscount {
      let expectedRange = switch miscount.expected {
        case .single(let expected):
          expected...expected
        case .range(let expected):
          ClosedRange<Int>(decoding: expected)
        }
      issueKind = .confirmationMiscounted(actual: miscount.actual, expected: expectedRange)
    } else {
      // TODO: improve fidelity of issue kind reporting (especially those without associated values)
      issueKind = .unconditional
    }
    let severity: Issue.Severity = switch issue.severity {
    case .warning:
      .warning
    case .error, nil:
      // Prior to 6.3, all Issues are errors
      .error
    }
    let sourceContext = SourceContext(
      backtrace: issue._backtrace.map { Backtrace(addresses: $0.symbolicatedAddresses.map(\.address)) },
      sourceLocation: sourceLocation.flatMap(SourceLocation.init)
    )
    self.init(
      kind: issueKind,
      severity: severity,
      comments: [],
      sourceContext: sourceContext
    )
    if issue.isKnown {
      let knownIssueComment = issue.knownIssueComment.map(Comment.init(rawValue:))
      self.knownIssueContext = Issue.KnownIssueContext(comment: knownIssueComment)
    }
  }
}
#endif
