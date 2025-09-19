//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(_TestingInfrastructure)
private import _TestingInfrastructure
#endif

extension Event {
  /// Attempt to handle an event encoded as JSON as if it had been generated in
  /// the current testing context.
  ///
  /// - Parameters:
  ///   - recordJSON: The JSON encoding of an event record.
  ///   - abi: The ABI version to use for decoding `recordJSON`.
  ///
  /// - Throws: Any error that prevented handling the encoded record.
  ///
  /// - Important: This function only handles a subset of event kinds.
  static func handle<V>(_ recordJSON: UnsafeRawBufferPointer, encodedWith abi: V.Type) throws where V: ABI.Version {
    let record = try JSON.decode(ABI.Record<V>.self, from: recordJSON)
    guard case let .event(event) = record.kind else {
      return
    }

    lazy var comments: [Comment] = event._comments?.map(Comment.init(rawValue:)) ?? []
    lazy var sourceContext = SourceContext(
      backtrace: nil, // A backtrace from the child process will have the wrong address space.
      sourceLocation: event._sourceLocation
    )
    lazy var skipInfo = SkipInfo(comment: comments.first, sourceContext: sourceContext)
    if let issue = event.issue {
      // Translate the issue back into a "real" issue and record it in the
      // parent process. This translation is, of course, lossy due to the ABI
      // and/or process boundary, but we make a best effort.
      let issueKind: Issue.Kind = if let error = issue._error {
        .errorCaught(error)
      } else {
        // TODO: improve fidelity of issue kind reporting (especially those without associated values)
        .unconditional
      }
      let severity: Issue.Severity = switch issue.severity {
      case .warning: .warning
      case nil, .error: .error
      }
      var issueCopy = Issue(kind: issueKind, severity: severity, comments: comments, sourceContext: sourceContext)
      if issue.isKnown {
        issueCopy.knownIssueContext = Issue.KnownIssueContext()
        issueCopy.knownIssueContext?.comment = issue._knownIssueComment.map(Comment.init(rawValue:))
      }
      issueCopy.record()
    } else if let attachment = event.attachment {
      Attachment.record(attachment, sourceLocation: event._sourceLocation!)
    } else if case .testCancelled = event.kind {
      _ = try? Test.cancel(with: skipInfo)
    } else if case .testCaseCancelled = event.kind {
      _ = try? Test.Case.cancel(with: skipInfo)
    }
  }

#if canImport(_TestingInfrastructure)
  /// The fallback event handler to set when Swift Testing is the active testing
  /// library.
  private static let _fallbackEventHandler: FallbackEventHandler = { recordJSONSchemaVersionNumber, recordJSONBaseAddress, recordJSONByteCount, _ in
    let abi = String(validatingCString: recordJSONSchemaVersionNumber)
      .flatMap(VersionNumber.init)
      .flatMap(ABI.version(forVersionNumber:))
    if let abi {
      let recordJSON = UnsafeRawBufferPointer(start: recordJSONBaseAddress, count: recordJSONByteCount)
      try! Self.handle(recordJSON, encodedWith: abi)
    }
  }
#endif

  /// The implementation of ``installFallbackEventHandler()``.
  private static let _installFallbackHandler: Bool = {
#if canImport(_TestingInfrastructure)
    _swift_testing_installFallbackEventHandler(Self._fallbackEventHandler)
#else
    false
#endif
  }()

  /// Install the testing library's fallback event handler.
  ///
  /// - Returns: Whether or not the handler was installed.
  static func installFallbackHandler() -> Bool {
    _installFallbackHandler
  }

  /// Post this event to the currently-installed fallback event handler.
  ///
  /// - Parameters:
  ///   - context: The context associated with this event.
  ///
  /// - Returns: Whether or not the fallback event handler was invoked. If the
  ///   currently-installed handler belongs to the testing library, returns
  ///   `false`.
  borrowing func postToFallbackHandler(in context: borrowing Context) -> Bool {
#if canImport(_TestingInfrastructure)
    guard let fallbackEventHandler = _swift_testing_getFallbackEventHandler() else {
      // No fallback event handler is installed.
      return false
    }
    if castCFunction(fallbackEventHandler, to: UnsafeRawPointer.self) == castCFunction(Self._fallbackEventHandler, to: UnsafeRawPointer.self) {
      // The fallback event handler belongs to Swift Testing, so we don't want
      // to call it on our own behalf.
      return false
    }

    // Encode the event as JSON and pass it to the handler.
    let encodeAndInvoke = ABI.CurrentVersion.eventHandler(encodeAsJSONLines: false) { recordJSON in
      fallbackEventHandler(
        String(describing: ABI.CurrentVersion.versionNumber),
        recordJSON.baseAddress!,
        recordJSON.count,
        nil
      )
    }
    encodeAndInvoke(self, context)
    return true
#else
    return false
#endif
  }
}
