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
private import _TestingInternals

extension ABI.v0 {
  /// The type of the entry point to the testing library used by tools that want
  /// to remain version-agnostic regarding the testing library.
  ///
  /// - Parameters:
  ///   - configurationJSON: A buffer to memory representing the test
  ///     configuration and options. If `nil`, a new instance is synthesized
  ///     from the command-line arguments to the current process.
  ///   - recordHandler: A JSON record handler to which is passed a buffer to
  ///     memory representing each record as described in `ABI/JSON.md`.
  ///
  /// - Returns: Whether or not the test run finished successfully.
  ///
  /// - Throws: Any error that occurred prior to running tests. Errors that are
  ///   thrown while tests are running are handled by the testing library.
  public typealias EntryPoint = @convention(thin) @Sendable (
    _ configurationJSON: UnsafeRawBufferPointer?,
    _ recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
  ) async throws -> Bool

  /// The entry point to the testing library used by tools that want to remain
  /// version-agnostic regarding the testing library.
  ///
  /// The value of this property is a Swift function that can be used by tools
  /// that do not link directly to the testing library and wish to invoke tests
  /// in a binary that has been loaded into the current process. The value of
  /// this property is accessible from C and C++ as a function with name
  /// `"swt_abiv0_getEntryPoint"` and can be dynamically looked up at runtime
  /// using `dlsym()` or a platform equivalent.
  ///
  /// The value of this property can be thought of as equivalent to a call to
  /// `swift test --event-stream-output-path` except that, instead of streaming
  /// JSON records to a named pipe or file, it streams them to an in-process
  /// callback.
  public static var entryPoint: EntryPoint {
    return { configurationJSON, recordHandler in
      try await _entryPoint(
        configurationJSON: configurationJSON,
        recordHandler: recordHandler
      ) == EXIT_SUCCESS
    }
  }
}

/// An exported C function that is the equivalent of
/// ``ABI/v0/entryPoint-swift.type.property``.
///
/// - Returns: The value of ``ABI/v0/entryPoint-swift.type.property`` cast to an
///   untyped pointer.
@_cdecl("swt_abiv0_getEntryPoint")
@usableFromInline func abiv0_getEntryPoint() -> UnsafeRawPointer {
  unsafeBitCast(ABI.v0.entryPoint, to: UnsafeRawPointer.self)
}

#if !SWT_NO_SNAPSHOT_TYPES
// MARK: - Xcode 16 Beta 1 compatibility

extension ABI.Xcode16Beta1 {
  /// An older signature for ``ABI/v0/EntryPoint-swift.typealias`` used by Xcode
  /// 16 Beta 1.
  ///
  /// - Warning: This type will be removed in a future update.
  @available(*, deprecated, message: "Use ABI.v0.EntryPoint instead.")
  typealias EntryPoint = @Sendable (
    _ argumentsJSON: UnsafeRawBufferPointer?,
    _ recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
  ) async throws -> CInt
}

/// An older signature for ``ABI/v0/entryPoint-swift.type.property`` used by
/// Xcode 16 Beta 1.
///
/// - Warning: This function will be removed in a future update.
@available(*, deprecated, message: "Use ABI.v0.entryPoint (swt_abiv0_getEntryPoint()) instead.")
@_cdecl("swt_copyABIEntryPoint_v0")
@usableFromInline func copyABIEntryPoint_v0() -> UnsafeMutableRawPointer {
  let result = UnsafeMutablePointer<ABI.Xcode16Beta1.EntryPoint>.allocate(capacity: 1)
  result.initialize { configurationJSON, recordHandler in
    try await _entryPoint(
      configurationJSON: configurationJSON,
      eventStreamVersionIfNil: -1,
      recordHandler: recordHandler
    )
  }
  return .init(result)
}
#endif

// MARK: -

/// A common implementation for ``ABI/v0/entryPoint-swift.type.property`` and
/// ``copyABIEntryPoint_v0()`` that provides Xcode 16 Beta 1 compatibility.
///
/// This function will be removed (with its logic incorporated into
/// ``ABI/v0/entryPoint-swift.type.property``) in a future update.
private func _entryPoint(
  configurationJSON: UnsafeRawBufferPointer?,
  eventStreamVersionIfNil: Int? = nil,
  recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
) async throws -> CInt {
  var args = try configurationJSON.map { configurationJSON in
    try JSON.decode(__CommandLineArguments_v0.self, from: configurationJSON)
  }

  // If the caller needs a nil event stream version to default to a specific
  // JSON schema, apply it here as if they'd specified it in the configuration
  // JSON blob.
  if let eventStreamVersionIfNil, args?.eventStreamVersion == nil {
    args?.eventStreamVersion = eventStreamVersionIfNil
  }

  let eventHandler = try eventHandlerForStreamingEvents(version: args?.eventStreamVersion, encodeAsJSONLines: false, forwardingTo: recordHandler)
  let exitCode = await entryPoint(passing: args, eventHandler: eventHandler)

  // To maintain compatibility with Xcode 16 Beta 1, suppress custom exit codes.
  // (This is also needed by ABI.v0.entryPoint to correctly treat the no-tests
  // as a successful run.)
  if exitCode == EXIT_NO_TESTS_FOUND {
    return EXIT_SUCCESS
  }
  return exitCode
}
#endif
