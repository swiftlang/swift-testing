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
private import Foundation

extension ABI.Version {
  static func eventHandler(
    encodeAsJSONLines: Bool,
    forwardingTo eventHandler: @escaping @Sendable (_ recordJSON: RawSpan) -> Void
  ) -> Event.Handler {
    // Encode as JSON Lines if requested.
    var eventHandlerCopy = eventHandler
    if encodeAsJSONLines {
      eventHandlerCopy = { @Sendable in JSON.asJSONLine($0, eventHandler) }
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
// MARK: - Xcode 16 compatibility

extension ABI.Xcode16 {
  static func eventHandler(
    encodeAsJSONLines: Bool,
    forwardingTo eventHandler: @escaping @Sendable (_ recordJSON: RawSpan) -> Void
  ) -> Event.Handler {
    return { event, context in
      if case .testDiscovered = event.kind {
        // Discard events of this kind rather than forwarding them to avoid a
        // crash in Xcode 16 (which does not expect any events to occur before
        // .runStarted.)
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
        eventHandler(eventAndContextJSON)
      }
    }
  }
}
#endif
#endif
