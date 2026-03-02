//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation) && (!SWT_NO_FILE_IO || !SWT_NO_ABI_ENTRY_POINT)
private import Foundation

extension ABI.Version {
  /// Create an event handler that encodes instances of ``Event`` as instances
  /// of ``ABI/Record`` and forwards them to a handler function.
  ///
  /// - Parameters:
  ///   - recordHandler: The record handler to forward events to.
  ///
  /// - Returns: An event handler.
  ///
  /// You can use this event handler with ``Configuration/eventHandler`` to
  /// automatically transform instances of ``Event`` to ``ABI/Record``.
  public static func eventHandler(
    forwardingTo recordHandler: @escaping @Sendable (_ record: ABI.Record<Self>) -> Void
  ) -> Event.Handler {
#if !SWT_NO_SNAPSHOT_TYPES && DEBUG
    precondition(self != ABI.Xcode16.self, "Attempted to create an ABI.Record-generating event handler for the Xcode 16 compatibility path.")
#endif

    let humanReadableOutputRecorder = Event.HumanReadableOutputRecorder()
    return { event, context in
      if case .testDiscovered = event.kind, let test = context.test {
        let testRecord = ABI.Record<Self>(encoding: test)
        recordHandler(testRecord)
      } else {
        let messages = humanReadableOutputRecorder.record(event, in: context, verbosity: 0)
        if let eventRecord = ABI.Record<Self>(encoding: event, in: context, messages: messages) {
          recordHandler(eventRecord)
        }
      }
    }
  }

  static func eventHandler(
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
    encodeAsJSONLines: Bool,
    forwardingTo recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
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
        eventAndContextJSON.withUnsafeBytes { eventAndContextJSON in
          recordHandler(eventAndContextJSON)
        }
      }
    }
  }
}
#endif
#endif
