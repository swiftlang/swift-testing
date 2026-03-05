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

#if !SWT_NO_INTEROP
  /// The fallback event handler that was installed in the current test process.
  private static let _activeFallbackEventHandler: SWTFallbackEventHandler? = {
    _swift_testing_getFallbackEventHandler()
  }()

  /// The fallback event handler to install when Swift Testing is the active
  /// testing library.
  private static let _ourFallbackEventHandler: SWTFallbackEventHandler = {
    recordJSONSchemaVersionNumber, recordJSONBaseAddress, recordJSONByteCount, _ in
    let version = String(validatingCString: recordJSONSchemaVersionNumber)
      .flatMap(VersionNumber.init)
      .flatMap { ABI.version(forVersionNumber: $0) }
    if let version {
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
        Issue.record(errorContext)
      }
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
    guard let fallbackEventHandler = Self._activeFallbackEventHandler else {
      return false
    }

    let isOurInstalledHandler =
      castCFunction(fallbackEventHandler, to: UnsafeRawPointer.self)
      == castCFunction(Self._ourFallbackEventHandler, to: UnsafeRawPointer.self)
    guard !isOurInstalledHandler else {
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
