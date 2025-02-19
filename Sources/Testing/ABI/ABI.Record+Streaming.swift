//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation) && (!SWT_NO_FILE_IO || !SWT_NO_ABI_ENTRY_POINT)
extension ABI.Version {
  /// Post-process encoded JSON and write it to a file.
  ///
  /// - Parameters:
  ///   - json: The JSON to write.
  ///   - file: The file to write to.
  ///
  /// - Throws: Whatever is thrown when writing to `file`.
  private static func _asJSONLine(_ json: UnsafeRawBufferPointer, _ eventHandler: (_ recordJSON: UnsafeRawBufferPointer) throws -> Void) rethrows {
    // We don't actually expect the JSON encoder to produce output containing
    // newline characters, so in debug builds we'll log a diagnostic message.
    if _slowPath(json.contains(where: \.isASCIINewline)) {
#if DEBUG && !SWT_NO_FILE_IO
      let message = Event.ConsoleOutputRecorder.warning(
        "JSON encoder produced one or more newline characters while encoding an event to JSON. Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new",
        options: .for(.stderr)
      )
#if SWT_TARGET_OS_APPLE
      try? FileHandle.stderr.write(message)
#else
      print(message)
#endif
#endif

      // Remove the newline characters to conform to JSON lines specification.
      var json = Array(json)
      json.removeAll(where: \.isASCIINewline)
      try json.withUnsafeBytes(eventHandler)
    } else {
      // No newlines found, no need to copy the buffer.
      try eventHandler(json)
    }
  }

  static func eventHandler(
    encodeAsJSONLines: Bool,
    forwardingTo eventHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
  ) -> Event.Handler {
    // Encode as JSON Lines if requested.
    var eventHandlerCopy = eventHandler
    if encodeAsJSONLines {
      eventHandlerCopy = { @Sendable in _asJSONLine($0, eventHandler) }
    }

    let humanReadableOutputRecorder = Event.HumanReadableOutputRecorder()
    return { [eventHandler = eventHandlerCopy] event, context in
      if case .testDiscovered = event.kind, let test = context.test {
        try? JSON.withEncoding(of: ABI.Record<Self>(encoding: test)) { testJSON in
          eventHandler(testJSON)
        }
      } else {
        let messages = humanReadableOutputRecorder.record(event, in: context, verbosity: 0)
        if let eventRecord = ABI.Record<Self>(encoding: event, in: context, messages: messages) {
          try? JSON.withEncoding(of: eventRecord, eventHandler)
        }
      }
    }
  }
}

#if !SWT_NO_SNAPSHOT_TYPES
// MARK: - Xcode 16 Beta 1 compatibility

extension ABI.Xcode16Beta1 {
  static func eventHandler(
    encodeAsJSONLines: Bool,
    forwardingTo eventHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
  ) -> Event.Handler {
    return { event, context in
      if case .testDiscovered = event.kind {
        // Discard events of this kind rather than forwarding them to avoid a
        // crash in Xcode 16 Beta 1 (which does not expect any events to occur
        // before .runStarted.)
        return
      }

      struct EventAndContextSnapshot: Codable {
        var event: Event.Snapshot
        var eventContext: Event.Context.Snapshot
      }
      let snapshot = EventAndContextSnapshot(
        event: Event.Snapshot(snapshotting: event),
        eventContext: Event.Context.Snapshot(snapshotting: context)
      )
      try? JSON.withEncoding(of: snapshot) { eventAndContextJSON in
        eventAndContextJSON.withUnsafeBytes { eventAndContextJSON in
          eventHandler(eventAndContextJSON)
        }
      }
    }
  }
}
#endif
#endif
