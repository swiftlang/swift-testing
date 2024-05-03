//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation) && !SWT_NO_ABI_ENTRY_POINT
/// The type of the entry point to the testing library used by tools that want
/// to remain version-agnostic regarding the testing library.
///
/// - Parameters:
///   - argumentsJSON: A buffer to memory that represents the JSON encoding of an
///     instance of `__CommandLineArguments_v0`. If `nil`, and creates a new instance
///     from the command-line arguments to the current process.
///   - eventHandler: An event handler that receives a memory buffer
///     representing each event and its context, as with ``Event/Handler``, but
///     encoded as JSON.
///
/// - Returns: The result of invoking the testing library. The type of this
///   value is subject to change.
///
/// This function examines the command-line arguments to the current process
/// and then invokes available tests in the current process.
///
/// - Warning: This function's signature and the structure of its JSON inputs
///   and outputs have not been finalized yet.@Comment{ QUERY: Has this been finalized? If so, can we remove the Warning? If not, we should make this a double-slash comment for initial release. }
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public typealias ABIEntryPoint_v0 = @Sendable (
  _ argumentsJSON: UnsafeRawBufferPointer?,
  _ eventHandler: @escaping @Sendable (_ eventAndContextJSON: UnsafeRawBufferPointer) -> Void
) async -> CInt

/// Get the entry point to the testing library used by tools that want to remain
/// version-agnostic regarding the testing library.
///
/// - Returns: A pointer to an instance of ``ABIEntryPoint_v0`` representing the
///   ABI-stable entry point to the testing library. The caller owns this memory
///   and is responsible for deinitializing and deallocating it when done.
///
/// This function can be used by tools that don't link directly to the testing
/// library and wish to invoke tests in a binary that has been loaded into the
/// current process. The function is emitted into the binary under the name
/// `"swt_copyABIEntryPoint_v0"` and can be dynamically looked up at runtime
/// using `dlsym()` or a platform equivalent.
///
/// The returned function can be thought of as equivalent to
/// `swift test --experimental-event-stream-output` except that, instead of
/// streaming events to a named pipe or file, it streams them to a callback.
///
/// - Warning: This function's signature and the structure of its JSON inputs
///   and outputs have not been finalized yet.@Comment{ QUERY: Has this been finalized? If so, can we remove the Warning? If not, we should make this a double-slash comment for initial release. }
@_cdecl("swt_copyABIEntryPoint_v0")
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public func copyABIEntryPoint_v0() -> UnsafeMutableRawPointer {
  let result = UnsafeMutablePointer<ABIEntryPoint_v0>.allocate(capacity: 1)
  result.initialize { argumentsJSON, eventHandler in
    let args = try! argumentsJSON.map { argumentsJSON in
      try JSON.decode(__CommandLineArguments_v0.self, from: argumentsJSON)
    }

    let eventHandler = eventHandlerForStreamingEvents_v0(to: eventHandler)
    return await entryPoint(passing: args, eventHandler: eventHandler)
  }
  return .init(result)
}
#endif

// MARK: - Experimental event streaming

#if canImport(Foundation) && (!SWT_NO_FILE_IO || !SWT_NO_ABI_ENTRY_POINT)
/// A type that contains an event snapshot and snapshots of the contents of an
/// event context suitable for streaming over JSON.
///
/// This function isn't part of the public interface of the testing library.
/// External adopters are not necessarily written in Swift and are expected to
/// decode the JSON produced for this type in implementation-specific ways.@Comment{ QUERY: Should we convert this text into a double-slashed comment? We don't typically talk about "external adopters" in the reference docs. }
struct EventAndContextSnapshot {
  /// A snapshot of the event.
  var event: Event.Snapshot

  /// A snapshot of the event context.
  var eventContext: Event.Context.Snapshot
}

extension EventAndContextSnapshot: Codable {}

/// Create an event handler that encodes events as JSON and forwards them to an
/// ABI-friendly event handler.
///
/// - Parameters:
///   - eventHandler: The event handler to forward events to. For more 
///     information, see ``ABIEntryPoint_v0``.
///
/// - Returns: An event handler.
///
/// The resulting event handler outputs data as JSON. For each event handled by
/// the resulting event handler, a JSON object representing it and its
/// associated context is created and is passed to `eventHandler`. These JSON
/// objects are guaranteed not to contain any ASCII newline characters (`"\r"`
/// or `"\n"`).
///
/// Note that `_eventHandlerForStreamingEvents_v0(toFileAtPath:)` calls this
/// function and performs additional postprocessing before writing JSON data.
func eventHandlerForStreamingEvents_v0(
  to eventHandler: @escaping @Sendable (_ eventAndContextJSON: UnsafeRawBufferPointer) -> Void
) -> Event.Handler {
  return { event, context in
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
#endif
