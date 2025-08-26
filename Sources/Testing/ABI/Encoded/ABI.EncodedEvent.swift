//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABI {
  /// A type implementing the JSON encoding of ``Event`` for the ABI entry point
  /// and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedEvent<V>: Sendable where V: ABI.Version {
    /// An enumeration describing the various kinds of event.
    ///
    /// Note that the set of encodable events is a subset of all events
    /// generated at runtime by the testing library.
    ///
    /// For descriptions of individual cases, see ``Event/Kind``.
    enum Kind: String, Sendable {
      case runStarted
      case testStarted
      case testCaseStarted
      case issueRecorded
      case valueAttached
      case testCaseEnded
      case testCaseCancelled = "_testCaseCancelled"
      case testEnded
      case testSkipped
      case testCancelled = "_testCancelled"
      case runEnded
    }

    /// The kind of event.
    var kind: Kind

    /// The instant at which the event occurred.
    var instant: EncodedInstant<V>

    /// The issue that occurred, if any.
    ///
    /// The value of this property is `nil` unless the value of the
    /// ``kind-swift.property`` property is ``Kind-swift.enum/issueRecorded``.
    var issue: EncodedIssue<V>?

    /// The value that was attached, if any.
    ///
    /// The value of this property is `nil` unless the value of the
    /// ``kind-swift.property`` property is ``Kind-swift.enum/valueAttached``.
    var attachment: EncodedAttachment<V>?

    /// Human-readable messages associated with this event that can be presented
    /// to the user.
    var messages: [EncodedMessage<V>]

    /// The ID of the test associated with this event, if any.
    var testID: EncodedTest<V>.ID?

    /// The ID of the test case associated with this event, if any.
    ///
    /// - Warning: Test cases are not yet part of the JSON schema.
    var _testCase: EncodedTestCase<V>?

    /// The comments the test author provided for this event, if any.
    ///
    /// - Warning: Comments at this level are not yet part of the JSON schema.
    var _comments: [String]?

    /// A source location associated with this event, if any.
    ///
    /// - Warning: Source locations at this level of the JSON schema are not yet
    ///   part of said JSON schema.
    var _sourceLocation: SourceLocation?

    init?(encoding event: borrowing Event, in eventContext: borrowing Event.Context, messages: borrowing [Event.HumanReadableOutputRecorder.Message]) {
      switch event.kind {
      case .runStarted:
        kind = .runStarted
      case .testStarted:
        kind = .testStarted
      case .testCaseStarted:
        if eventContext.test?.isParameterized == false {
          return nil
        }
        kind = .testCaseStarted
      case let .issueRecorded(recordedIssue):
        kind = .issueRecorded
        issue = EncodedIssue(encoding: recordedIssue, in: eventContext)
        _comments = recordedIssue.comments.map(\.rawValue)
        _sourceLocation = recordedIssue.sourceLocation
      case let .valueAttached(attachment):
        kind = .valueAttached
        self.attachment = EncodedAttachment(encoding: attachment, in: eventContext)
        _sourceLocation = attachment.sourceLocation
      case .testCaseEnded:
        if eventContext.test?.isParameterized == false {
          return nil
        }
        kind = .testCaseEnded
      case let .testCaseCancelled(skipInfo):
        kind = .testCaseCancelled
        _comments = Array(skipInfo.comment).map(\.rawValue)
        _sourceLocation = skipInfo.sourceLocation
      case .testEnded:
        kind = .testEnded
      case let .testSkipped(skipInfo):
        kind = .testSkipped
        _comments = Array(skipInfo.comment).map(\.rawValue)
        _sourceLocation = skipInfo.sourceLocation
      case let .testCancelled(skipInfo):
        kind = .testCancelled
        _comments = Array(skipInfo.comment).map(\.rawValue)
        _sourceLocation = skipInfo.sourceLocation
      case .runEnded:
        kind = .runEnded
      default:
        return nil
      }
      instant = EncodedInstant(encoding: event.instant)
      self.messages = messages.map(EncodedMessage.init)
      testID = event.testID.map(EncodedTest.ID.init)
      if eventContext.test?.isParameterized == true {
        _testCase = eventContext.testCase.map(EncodedTestCase.init)
      }
    }
  }
}

// MARK: - Codable

extension ABI.EncodedEvent: Codable {}
extension ABI.EncodedEvent.Kind: Codable {}
