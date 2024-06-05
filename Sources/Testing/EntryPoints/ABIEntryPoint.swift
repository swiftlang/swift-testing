//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
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
///   - argumentsJSON: A buffer to memory representing the JSON encoding of an
///     instance of `__CommandLineArguments_v0`. If `nil`, a new instance is
///     created from the command-line arguments to the current process.
///   - recordHandler: A JSON record handler to which is passed a buffer to
///     memory representing each record as described in `ABI/JSON.md`.
///
/// - Returns: The result of invoking the testing library. The type of this
///   value is subject to change.
///
/// - Throws: Any error that occurred prior to running tests. Errors that are
///   thrown while tests are running are handled by the testing library.
///
/// This function examines the command-line arguments to the current process
/// and then invokes available tests in the current process.
///
/// - Warning: This function's signature and the structure of its JSON inputs
///   and outputs have not been finalized yet.
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public typealias ABIEntryPoint_v0 = @Sendable (
  _ argumentsJSON: UnsafeRawBufferPointer?,
  _ recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
) async throws -> CInt

/// Get the entry point to the testing library used by tools that want to remain
/// version-agnostic regarding the testing library.
///
/// - Returns: A pointer to an instance of ``ABIEntryPoint_v0`` representing the
///   ABI-stable entry point to the testing library. The caller owns this memory
///   and is responsible for deinitializing and deallocating it when done.
///
/// This function can be used by tools that do not link directly to the testing
/// library and wish to invoke tests in a binary that has been loaded into the
/// current process. The function is emitted into the binary under the name
/// `"swt_copyABIEntryPoint_v0"` and can be dynamically looked up at runtime
/// using `dlsym()` or a platform equivalent.
///
/// The returned function can be thought of as equivalent to
/// `swift test --experimental-event-stream-output` except that, instead of
/// streaming JSON records to a named pipe or file, it streams them to an
/// in-process callback.
///
/// - Warning: This function's signature and the structure of its JSON inputs
///   and outputs have not been finalized yet.
@_cdecl("swt_copyABIEntryPoint_v0")
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public func copyABIEntryPoint_v0() -> UnsafeMutableRawPointer {
  let result = UnsafeMutablePointer<ABIEntryPoint_v0>.allocate(capacity: 1)
  result.initialize { argumentsJSON, recordHandler in
    let args = try argumentsJSON.map { argumentsJSON in
      try JSON.decode(__CommandLineArguments_v0.self, from: argumentsJSON)
    }

    let eventHandler = try eventHandlerForStreamingEvents(version: args?.experimentalEventStreamVersion, forwardingTo: recordHandler)
    return await entryPoint(passing: args, eventHandler: eventHandler)
  }
  return .init(result)
}
#endif
