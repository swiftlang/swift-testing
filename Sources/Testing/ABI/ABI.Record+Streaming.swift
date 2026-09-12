//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_ABI_JSON_SCHEMA
extension ABI.Version {
  public static func eventHandler(
    forwardingTo recordHandler: @escaping @Sendable (_ record: ABI.Record<Self>) -> Void
  ) -> Event.Handler {
    var humanReadableOutputRecorder: Event.HumanReadableOutputRecorder?
    if alwaysEncodeMessagesField {
      humanReadableOutputRecorder = Event.HumanReadableOutputRecorder()
    }
    return { [humanReadableOutputRecorder] event, context in
      var messages: [Event.HumanReadableOutputRecorder.Message] = []
      if let humanReadableOutputRecorder {
        var configuration = Configuration()
        configuration.verbosity = 0
        messages = humanReadableOutputRecorder.record(event, in: context, configuration: configuration)
      }
      if let record = ABI.Record<Self>(encoding: event, in: context, messages: messages) {
        recordHandler(record)
      }
    }
  }

  public static func eventHandler(
    encodeAsJSONLines: Bool,
    forwardingTo recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
  ) -> Event.Handler {
    // Encode as JSON Lines if requested.
    var recordHandlerCopy = recordHandler
    if encodeAsJSONLines {
      recordHandlerCopy = { @Sendable in JSON.asJSONLine($0, recordHandler) }
    }

    return eventHandler { [recordHandler = recordHandlerCopy] record in
      try? JSON.withEncoding(of: record) { recordJSON in
        recordHandler(recordJSON)
      }
    }
  }
}

#if !SWT_NO_SNAPSHOT_TYPES
// MARK: - Xcode 16 compatibility

extension ABI.Xcode16 {
  static func eventHandler(
    forwardingTo recordHandler: @escaping @Sendable (_ record: ABI.Record<Self>) -> Void
  ) -> Event.Handler {
    preconditionFailure("Attempted to create an ABI.Record-generating event handler for the Xcode 16 compatibility path.")
  }

  static func eventHandler(
    encodeAsJSONLines: Bool,
    forwardingTo recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
  ) -> Event.Handler {
    return { event, context in
      switch event.kind {
      case .testDiscovered, .metadataRecorded:
        // Discard events of this kind rather than forwarding them to avoid a
        // crash in Xcode 16 (which does not expect any events to occur before
        // .runStarted.)
        return
      default:
        break
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
        recordHandler(eventAndContextJSON)
      }
    }
  }
}
#endif
#endif
