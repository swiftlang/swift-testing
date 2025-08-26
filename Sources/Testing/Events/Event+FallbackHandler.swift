//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _Testing_ExperimentalInfrastructure

extension Event {
  /// The implementation of ``fallbackEventHandler``.
  ///
  /// - Parameters:
  ///   - abi: The ABI version to use for decoding `recordJSON`.
  ///   - recordJSON: The JSON encoding of an event record.
  ///
  /// - Throws: Any error that prevented handling the encoded record.
  private static func _fallbackEventHandler<V>(_ abi: V.Type, _ recordJSON: UnsafeRawBufferPointer) throws where V: ABI.Version {
    let record = try JSON.decode(ABI.Record<ABI.CurrentVersion>.self, from: recordJSON)
    guard case let .event(event) = record.kind else {
      return
    }
    switch event.kind {
    case .issueRecorded:
      Issue(event)?.record()
    case .valueAttached:
      if let attachment = event.attachment {
        Attachment.record(attachment, sourceLocation: attachment._sourceLocation ?? .__here())
      }
    default:
      // Not handled here.
      break
    }
  }

  /// The fallback event handler to set when Swift Testing is the active testing
  /// library.
  private static let _fallbackEventHandler: FallbackEventHandler = { recordJSONSchemaVersionNumber, recordJSONBaseAddress, recordJSONByteCount, _ in
    let abi = String(validatingCString: recordJSONSchemaVersionNumber)
      .flatMap(VersionNumber.init)
      .flatMap(ABI.version(forVersionNumber:))
    if let abi {
      let recordJSON = UnsafeRawBufferPointer(start: recordJSONBaseAddress, count: recordJSONByteCount)
      try! Self._fallbackEventHandler(abi, recordJSON)
    }
  }

  /// The implementation of ``installFallbackEventHandler()``.
  private static let _installFallbackHandler: Bool = {
    _Testing_ExperimentalInfrastructure.installFallbackEventHandler(Self._fallbackEventHandler)
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
    guard let fallbackEventHandler = _Testing_ExperimentalInfrastructure.fallbackEventHandler() else {
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
  }
}
