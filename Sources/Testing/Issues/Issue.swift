//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type describing a failure or warning which occurred during a test.
public struct Issue: Sendable {
  /// Kinds of issues which may be recorded.
  public enum Kind: Sendable {
    /// An issue which occurred unconditionally, for example by using
    /// ``Issue/record(_:fileID:filePath:line:column:)``.
    case unconditional

    /// An issue due to a failed expectation, such as those produced by
    /// ``expect(_:_:sourceLocation:)``.
    ///
    /// - Parameters:
    ///   - expectation: The expectation that failed.
    case expectationFailed(_ expectation: Expectation)

    /// An issue due to a confirmation being confirmed the wrong number of
    /// times.
    ///
    /// - Parameters:
    ///   - actual: The number of times ``Confirmation/confirm(count:)`` was
    ///     actually called.
    ///   - expected: The expected number of times
    ///     ``Confirmation/confirm(count:)`` should have been called.
    ///
    /// This issue can occur when calling
    /// ``confirmation(_:expectedCount:fileID:filePath:line:column:_:)`` when
    /// the confirmation passed to these functions' `body` closures is confirmed
    /// too few or too many times.
    case confirmationMiscounted(actual: Int, expected: Int)

    /// An issue due to an `Error` being thrown by a test function and caught by
    /// the testing library.
    ///
    /// - Parameters:
    ///   - error: The error which was associated with this issue.
    case errorCaught(_ error: any Error)

    /// An issue due to a test reaching its time limit and timing out.
    ///
    /// - Parameters:
    ///   - timeLimitComponents: The time limit reached by the test.
    ///
    /// @Comment {
    ///   - Bug: The associated value of this enumeration case should be an
    ///     instance of `Duration`, but the testing library's deployment target
    ///     predates the introduction of that type.
    /// }
    case timeLimitExceeded(timeLimitComponents: (seconds: Int64, attoseconds: Int64))

    /// A known issue was expected, but was not recorded.
    case knownIssueNotRecorded

    /// An issue occurred due to misuse of the testing library.
    case apiMisused

    /// An issue due to a failure in the underlying system, not due to a failure
    /// within the tests being run.
    case system
  }

  /// The kind of issue this value represents.
  public var kind: Kind

  /// Any comments provided by the developer and associated with this issue.
  ///
  /// If no comment was supplied when the issue occurred, the value of this
  /// property is the empty array.
  public var comments: [Comment]

  /// A ``SourceContext`` indicating where and how this issue occurred.
  public var sourceContext: SourceContext

  /// Whether or not this issue is known to occur.
  public var isKnown = false

  /// Initialize an issue instance with the specified details.
  ///
  /// - Parameters:
  ///   - kind: The kind of issue this value represents.
  ///   - comments: An array of comments describing the issue. This array may be
  ///     empty.
  ///   - sourceContext: A ``SourceContext`` indicating where and how this issue
  ///     occurred. This defaults to a default source context returned by
  ///     calling ``SourceContext/init(backtrace:sourceLocation:)`` with zero
  ///     arguments.
  init(
    kind: Kind,
    comments: [Comment],
    sourceContext: SourceContext = .init()
  ) {
    self.kind = kind
    self.comments = comments
    self.sourceContext = sourceContext
  }

  /// The error which was associated with this issue, if any.
  ///
  /// The value of this property is non-`nil` when ``kind-swift.property`` is
  /// ``Kind-swift.enum/errorCaught(_:)``.
  public var error: (any Error)? {
    if case let .errorCaught(error) = kind {
      return error
    }
    return nil
  }

  /// The location in source where this issue occurred, if available.
  public var sourceLocation: SourceLocation? {
    get {
      sourceContext.sourceLocation
    }
    set {
      sourceContext.sourceLocation = newValue
    }
  }
}

// MARK: - CustomStringConvertible, CustomDebugStringConvertible

extension Issue: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    if comments.isEmpty {
      return String(describing: kind)
    }
    let joinedComments = comments.lazy
      .map(\.rawValue)
      .joined(separator: "\n")
    return "\(kind): \(joinedComments)"
  }

  public var debugDescription: String {
    if comments.isEmpty {
      return "\(kind)\(sourceLocation.map { " at \($0)" } ?? "")"
    }
    let joinedComments: String = comments.lazy
      .map(\.rawValue)
      .joined(separator: "\n")
    return "\(kind)\(sourceLocation.map { " at \($0)" } ?? ""): \(joinedComments)"
  }
}

extension Issue.Kind: CustomStringConvertible {
  public var description: String {
    switch self {
    case .unconditional:
      "Unconditionally failed"
    case let .expectationFailed(expectation):
      if let mismatchedErrorDescription = expectation.mismatchedErrorDescription {
        "Expectation failed: \(mismatchedErrorDescription)"
      } else if let expandedExpressionDescription = expectation.expandedExpressionDescription {
        "Expectation failed: \(expandedExpressionDescription)"
      } else if let sourceCode = expectation.sourceCode {
        "Expectation failed: \(sourceCode)"
      } else {
        "Expectation failed"
      }
    case let .confirmationMiscounted(actual: actual, expected: expected):
      "Confirmation was confirmed \(actual.counting("time")), but expected to be confirmed \(expected.counting("time"))"
    case let .errorCaught(error):
      "Caught error: \(error)"
    case let .timeLimitExceeded(timeLimitComponents: timeLimitComponents):
      "Time limit was exceeded: \(descriptionOfTimeComponents(timeLimitComponents))"
    case .knownIssueNotRecorded:
      "Known issue was not recorded"
    case .apiMisused:
      "An API was misused"
    case .system:
      "A system failure occurred"
    }
  }
}

// MARK: - Codable

extension Issue: Codable {}

extension Issue.Kind: Codable {
  enum CodingKeys: CodingKey {
    case unconditional
    case expectationFailed
    case confirmationMiscounted
    case errorCaught
    case timeLimitExceeded
    case knownIssueNotRecorded
    case apiMisused
    case system

    enum ExpectationFailedKeys: CodingKey {
      case expectation
    }

    enum ConfirmationMiscountedKeys: CodingKey {
      case actual
      case expected
    }

    enum ErrorCaughtKeys: CodingKey {
      case error
    }

    enum TimeLimitExceededKeys: CodingKey {
      case seconds
      case attoseconds
    }
  }

  /// We can't encode / decode arbitrary Errors, so when we encode them we use
  /// their String representation (via `String(describing:)`), and when we
  /// decode them we use this type (since we need a concrete type, and the
  /// original type might not even exist where the decoding is happening).
  @_spi(ExperimentalTestRunning)
  public struct DecodedError: Error, Sendable, Codable {
    let stringRepresentation: String
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if try container.decodeIfPresent(Bool.self, forKey: .unconditional) != nil {
      self = .unconditional
    } else if let expectationFailedContainer = try? container.nestedContainer(keyedBy: CodingKeys.ExpectationFailedKeys.self,
                                                                              forKey: .expectationFailed) {
      self = .expectationFailed(try expectationFailedContainer.decode(Expectation.self, forKey: .expectation))
    } else if let confirmationMiscountedContainer = try? container.nestedContainer(keyedBy: CodingKeys.ConfirmationMiscountedKeys.self,
                                                                                   forKey: .confirmationMiscounted) {
      self = .confirmationMiscounted(actual: try confirmationMiscountedContainer.decode(Int.self,
                                                                                        forKey: .actual),
                                     expected: try confirmationMiscountedContainer.decode(Int.self,
                                                                                          forKey: .expected))
    } else if let errorCaught = try? container.nestedContainer(keyedBy: CodingKeys.ErrorCaughtKeys.self,
                                                               forKey: .errorCaught) {
      self = .errorCaught(try errorCaught.decode(DecodedError.self, forKey: .error))
    } else if let timeLimitExceededContainer = try? container.nestedContainer(keyedBy: CodingKeys.TimeLimitExceededKeys.self,
                                                                              forKey: .timeLimitExceeded) {
      self = .timeLimitExceeded(timeLimitComponents: (seconds: try timeLimitExceededContainer.decode(Int64.self,
                                                                                                     forKey: .seconds),
                                                      attoseconds: try timeLimitExceededContainer.decode(Int64.self,
                                                                                                         forKey: .attoseconds)))
    } else if try container.decodeIfPresent(Bool.self, forKey: .knownIssueNotRecorded) != nil {
      self = .knownIssueNotRecorded
    } else if try container.decodeIfPresent(Bool.self, forKey: .apiMisused) != nil {
      self = .apiMisused
    } else if try container.decodeIfPresent(Bool.self, forKey: .system) != nil {
      self = .system
    } else {
      throw DecodingError.valueNotFound(
        Self.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Value found did not match any of the existing cases for Issue.Kind."
        )
      )
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .unconditional:
      try container.encode(true, forKey: .unconditional)
    case let .expectationFailed(expectation):
      var errorCaughtContainer = container.nestedContainer(keyedBy: CodingKeys.ExpectationFailedKeys.self,
                                                           forKey: .expectationFailed)
      try errorCaughtContainer.encode(expectation, forKey: .expectation)
    case let .confirmationMiscounted(actual, expected):
      var confirmationMiscountedContainer = container.nestedContainer(keyedBy: CodingKeys.ConfirmationMiscountedKeys.self,
                                                                      forKey: .confirmationMiscounted)
      try confirmationMiscountedContainer.encode(actual, forKey: .actual)
      try confirmationMiscountedContainer.encode(expected, forKey: .expected)
    case let .errorCaught(error):
      var errorCaughtContainer = container.nestedContainer(keyedBy: CodingKeys.ErrorCaughtKeys.self, forKey: .errorCaught)
      let encodeError = DecodedError(stringRepresentation: String(describing: error))
      try errorCaughtContainer.encode(encodeError, forKey: .error)
    case let .timeLimitExceeded(timeLimitComponents):
      var timeLimitExceededContainer = container.nestedContainer(keyedBy: CodingKeys.TimeLimitExceededKeys.self,
                                                                 forKey: .timeLimitExceeded)
      try timeLimitExceededContainer.encode(timeLimitComponents.seconds, forKey: .seconds)
      try timeLimitExceededContainer.encode(timeLimitComponents.attoseconds, forKey: .attoseconds)
    case .knownIssueNotRecorded:
      try container.encode(true, forKey: .knownIssueNotRecorded)
    case .apiMisused:
      try container.encode(true, forKey: .apiMisused)
    case .system:
      try container.encode(true, forKey: .system)
    }
  }
}
