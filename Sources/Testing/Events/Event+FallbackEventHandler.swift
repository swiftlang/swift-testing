//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

extension Event {
  /// Attempt to handle an event encoded as JSON as if it had been generated in
  /// the current testing context.
  ///
  /// If the event contains an issue, handle it, but also record a warning issue
  /// notifying the user that interop was performed.
  ///
  /// - Parameters:
  ///   - recordJSON: The JSON encoding of an event record.
  ///   - version: The ABI version to use for decoding `recordJSON`.
  ///
  /// - Throws: Any error that prevented handling the encoded record.
  ///
  /// - Important: This function only handles a subset of event kinds.
  static func handle<V>(_ recordJSON: UnsafeRawBufferPointer, encodedWith version: V.Type) throws
  where V: ABI.Version {
    let record = try JSON.decode(ABI.Record<V>.self, from: recordJSON)
    guard case .event(let event) = record.kind,
          let issue = Issue(decoding: event) else {
      return
    }

    // For the time being, assume that foreign test events originate from XCTest
    let warnForXCTestUsageIssue = {
      return Issue(
        kind: .apiMisused, severity: .warning,
        comments: [
          "XCTest API was used in a Swift Testing test. Adopt Swift Testing primitives, such as #expect, instead."
        ], sourceContext: issue.sourceContext
      )
    }()

    issue.record()
    warnForXCTestUsageIssue.record()
  }

  /// Get the best available source location to use when diagnosing an issue
  /// decoding a bad record JSON blob.
  ///
  /// - Parameters:
  ///   - recordJSON: The undecodable JSON.
  ///
  /// - Returns: A source location to use when reporting an issue about
  ///   `recordJSON`.
  private static func _bestAvailableSourceLocation(forInvalidRecordJSON recordJSON: UnsafeRawBufferPointer) -> SourceLocation {
    // TODO: try to actually extract a source location from arbitrary JSON?

    // If there's a test associated with the current task, it should have a
    // source location associated with it.
    if let test = Test.current {
      return test.sourceLocation
    }

    return SourceLocation(fileID: "<unknown>/<unknown>", filePath: "<unknown>", line: 1, column: 1)
  }

#if !SWT_NO_INTEROP
  /// The fallback event handler to install when Swift Testing is the active
  /// testing library.
  private static let _ourFallbackEventHandler: SWTFallbackEventHandler = {
    recordJSONSchemaVersionNumber, recordJSONBaseAddress, recordJSONByteCount, _ in
    let version = String(validatingCString: recordJSONSchemaVersionNumber)
      .flatMap(VersionNumber.init)
      .flatMap { ABI.version(forVersionNumber: $0) } ?? ABI.v0.self
    let recordJSON = UnsafeRawBufferPointer(
      start: recordJSONBaseAddress, count: recordJSONByteCount)
    do {
      try Self.handle(recordJSON, encodedWith: version)
    } catch {
      // Surface otherwise "unhandleable" records instead of dropping them silently
      let errorContext: Comment = """
        Another test library reported a test event that Swift Testing could not decode. Inspect the payload to determine if this was a test assertion failure.

        Error:
        \(error)

        Raw payload:
        \(recordJSON)
        """

      // Try to figure out a reasonable source context for this issue.
      let sourceContext = SourceContext(
        backtrace: .current(),
        sourceLocation: _bestAvailableSourceLocation(forInvalidRecordJSON: recordJSON)
      )

      // Record the issue.
      Issue(
        kind: .system,
        comments: [errorContext],
        sourceContext: sourceContext
      ).record()
    }
  }
#endif

  /// The implementation of ``installFallbackEventHandler()``.
  private static let _installFallbackEventHandler: Bool = {
#if !SWT_NO_INTEROP
    if Environment.flag(named: "SWT_EXPERIMENTAL_INTEROP_ENABLED") == true {
      return _swift_testing_installFallbackEventHandler(Self._ourFallbackEventHandler)
    }
#endif
    return false
  }()

  /// Installs the Swift Testing's fallback event handler, indicating that it is
  /// the active testing library. You can only try installing the handler once,
  /// so extra attempts will return the status from the first attempt.
  ///
  /// The handler receives events created by other testing libraries and tries
  /// to emulate behaviour in Swift Testing where possible. For example, an
  /// `XCTAssert` failure reported by the XCTest API can be recorded as an
  /// `Issue` in Swift Testing.
  ///
  /// - Returns: Whether the installation succeeded. The installation typically
  ///   fails because the _TestingInterop library was not available at runtime or
  ///   another testing library has already installed a fallback event handler.
  static func installFallbackEventHandler() -> Bool {
    _installFallbackEventHandler
  }

  /// Post this event to the currently-installed fallback event handler.
  ///
  /// - Parameters:
  ///   - context: The context associated with this event.
  ///
  /// - Returns: Whether or not the fallback event handler was invoked. If the
  ///   currently-installed handler belongs to the testing library, returns
  ///   `false`.
  borrowing func postToFallbackEventHandler(in context: borrowing Context) -> Bool {
#if !SWT_NO_INTEROP
    return Self._postToFallbackEventHandler?(self, context) != nil
#else
    return false
#endif
  }

#if !SWT_NO_INTEROP
  /// The implementation of ``postToFallbackEventHandler(in:)`` that actually
  /// invokes the installed fallback event handler.
  ///
  /// If there was no fallback event handler installed, or if the installed
  /// handler belongs to the testing library (and so shouldn't be called by us),
  /// the value of this property is `nil`.
  private static let _postToFallbackEventHandler: Event.Handler? = {
    guard let fallbackEventHandler = _swift_testing_getFallbackEventHandler() else {
      return nil
    }

    let fallbackEventHandlerAddress = castCFunction(fallbackEventHandler, to: UnsafeRawPointer.self)
    let ourFallbackEventHandlerAddress = castCFunction(Self._ourFallbackEventHandler, to: UnsafeRawPointer.self)
    if fallbackEventHandlerAddress == ourFallbackEventHandlerAddress {
      // The fallback event handler belongs to Swift Testing, so we don't want
      // to call it on our own behalf.
      return nil
    }

    // Encode the event as JSON and pass it to the handler.
    return ABI.CurrentVersion.eventHandler(encodeAsJSONLines: false) { recordJSON in
      fallbackEventHandler(
        String(describing: ABI.CurrentVersion.versionNumber),
        recordJSON.baseAddress!,
        recordJSON.count,
        nil
      )
    }
  }()
#endif
}
