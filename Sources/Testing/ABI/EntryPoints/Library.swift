//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) private import _TestDiscovery
internal import _TestingInternals

/// A type representing a testing library such as Swift Testing or XCTest.
@_spi(Experimental)
@frozen public struct Library: Sendable {
  /// The underlying instance of ``Library/Record``.
  ///
  /// - Important: The in-memory layout of ``Library`` must _exactly_ match the
  ///   layout of ``Library/Record``. As such, ``Library`` must not contain any
  ///   other stored properties.
  nonisolated(unsafe) var rawValue: Record

  /// The human-readable name of this library.
  ///
  /// For example, the value of this property for an instance of this type that
  /// represents the Swift Testing library is `"Swift Testing"`.
  public var name: String {
    String(validatingCString: rawValue.name) ?? ""
  }

  /// The canonical form of the "hint" to run the testing library's tests at
  /// runtime.
  ///
  /// For example, the value of this property for an instance of this type that
  /// represents the Swift Testing library is `"swift-testing"`.
  @_spi(ForToolsIntegrationOnly)
  public var canonicalHint: String {
    String(validatingCString: rawValue.canonicalHint) ?? ""
  }

#if !SWT_NO_RUNTIME_LIBRARY_DISCOVERY
  /// Call the entry point function of this library.
  ///
  /// - Parameters:
  ///   - args: The arguments to pass to the testing library as its
  ///     configuration JSON.
  ///   - recordHandler: A callback to invoke once per record.
  ///
  /// - Returns: A process exit code such as `EXIT_SUCCESS`.
  ///
  /// - Warning: The signature of this function is subject to change as
  ///   `__CommandLineArguments_v0` is not a stable interface.
  @_spi(ForToolsIntegrationOnly)
  public func callEntryPoint(
    passing args: __CommandLineArguments_v0? = nil,
    recordHandler: (@Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void)? = nil
  ) async -> CInt {
    do {
      return try await _callEntryPoint(passing: args, recordHandler: recordHandler)
    } catch {
      // TODO: more advanced error recovery?
      return EXIT_FAILURE
    }
  }

  /// The implementation of ``callEntryPoint(passing:recordHandler:)``.
  ///
  /// - Parameters:
  /// 	- args: The arguments to pass to the testing library as its
  ///     configuration JSON.
  ///   - recordHandler: A callback to invoke once per record.
  ///
  /// - Returns: A process exit code such as `EXIT_SUCCESS`.
	private func _callEntryPoint(
    passing args: __CommandLineArguments_v0?,
    recordHandler: (@Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void)?
  ) async throws -> CInt {
    var recordHandler = recordHandler

    let args = try args ?? parseCommandLineArguments(from: CommandLine.arguments)

    // Event stream output
    // Automatically write record JSON as JSON lines to the event stream if
    // specified by the user.
    if let eventStreamOutputPath = args.eventStreamOutputPath {
      let file = try FileHandle(forWritingAtPath: eventStreamOutputPath)
      recordHandler = { [oldRecordHandler = recordHandler] recordJSON in
        JSON.asJSONLine(recordJSON) { recordJSON in
          _ = try? file.withLock {
            try file.write(recordJSON)
            try file.write("\n")
          }
        }
        oldRecordHandler?(recordJSON)
      }
    }

    let configurationJSON = try JSON.withEncoding(of: args) { configurationJSON in
      configurationJSON.withMemoryRebound(to: UInt8.self) { Array($0) }
    }

    let resultJSON: [UInt8] = await withCheckedContinuation { continuation in
      struct Context {
        var continuation: CheckedContinuation<[UInt8], Never>
        var recordHandler: (@Sendable (UnsafeRawBufferPointer) -> Void)?
      }
      let context = Unmanaged.passRetained(
        Context(
          continuation: continuation,
          recordHandler: recordHandler
        ) as AnyObject
      ).toOpaque()
      configurationJSON.withUnsafeBytes { configurationJSON in
        rawValue.entryPoint(
          configurationJSON.baseAddress!,
          configurationJSON.count,
          0,
          context,
          /* recordJSONHandler: */ { recordJSON, recordJSONByteCount, _, context in
            guard let context = Unmanaged<AnyObject>.fromOpaque(context!).takeUnretainedValue() as? Context else {
              return
            }
            let recordJSON = UnsafeRawBufferPointer(start: recordJSON, count: recordJSONByteCount)
            context.recordHandler?(recordJSON)
          },
          /* completionHandler: */ { resultJSON, resultJSONByteCount, _, context in
            guard let context = Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as? Context else {
              return
            }
            // TODO: interpret more complex results than a process exit code
            let resultJSON = [UInt8](UnsafeRawBufferPointer(start: resultJSON, count: resultJSONByteCount))
            context.continuation.resume(returning: resultJSON)
          }
        )
      }
    }

    do {
      return try resultJSON.withUnsafeBytes { resultJSON in
        try JSON.decode(CInt.self, from: resultJSON)
      }
    } catch {
      // TODO: more advanced error recovery?
      return EXIT_FAILURE
    }
  }
#endif
}

#if !SWT_NO_RUNTIME_LIBRARY_DISCOVERY
// MARK: - C structure

extension Library {
  @usableFromInline typealias EntryPoint = @convention(c) (
    _ configurationJSON: UnsafeRawPointer,
    _ configurationJSONByteCount: Int,
    _ reserved: UInt,
    _ context: UnsafeRawPointer?,
    _ recordJSONHandler: EntryPointRecordJSONHandler,
    _ completionHandler: EntryPointCompletionHandler
  ) -> Void

  @usableFromInline typealias EntryPointRecordJSONHandler = @convention(c) (
    _ recordJSON: UnsafeRawPointer,
    _ recordJSONByteCount: Int,
    _ reserved: UInt,
    _ context: UnsafeRawPointer?
  ) -> Void

  @usableFromInline typealias EntryPointCompletionHandler = @convention(c) (
    _ resultJSON: UnsafeRawPointer,
    _ resultJSONByteCount: Int,
    _ reserved: UInt,
    _ context: UnsafeRawPointer?
  ) -> Void

  /// A type that provides the C-compatible in-memory layout of the ``Library``
  /// Swift type.
  @usableFromInline typealias Record = (
    name: UnsafePointer<CChar>,
    canonicalHint: UnsafePointer<CChar>,
    entryPoint: EntryPoint,
    reserved: (UInt, UInt, UInt, UInt, UInt)
  )
}

// MARK: - Discovery

/// A helper protocol that prevents the conformance of ``Library`` to
/// ``DiscoverableAsTestContent`` from being emitted into the testing library's
/// Swift module or interface files.
private protocol _DiscoverableAsTestContent: DiscoverableAsTestContent {}

extension Library: _DiscoverableAsTestContent {
  fileprivate static var testContentKind: TestContentKind {
    "main"
  }

  fileprivate typealias TestContentAccessorHint = UnsafePointer<CChar>
}

@_spi(Experimental)
extension Library {
  /// Perform a one-time check that the in-memory layout of ``Library`` matches
  /// that of ``Library/Record``.
  private static let _validateMemoryLayout: Void = {
    assert(MemoryLayout<Library>.size == MemoryLayout<Library.Record>.size, "Library.size (\(MemoryLayout<Library>.size)) != Library.Record.size (\(MemoryLayout<Library.Record>.size)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    assert(MemoryLayout<Library>.stride == MemoryLayout<Library.Record>.stride, "Library.stride (\(MemoryLayout<Library>.stride)) != Library.Record.stride (\(MemoryLayout<Library.Record>.stride)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    assert(MemoryLayout<Library>.alignment == MemoryLayout<Library.Record>.alignment, "Library.alignment (\(MemoryLayout<Library>.alignment)) != Library.Record.alignment (\(MemoryLayout<Library.Record>.alignment)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
  }()

  /// Create an instance of this type representing the testing library with the
  /// given hint.
  ///
  /// - Parameters:
  /// 	- hint: The hint to match against such as `"swift-testing"`.
  ///
  /// If no matching testing library is found, this initializer returns `nil`.
  @_spi(ForToolsIntegrationOnly)
  public init?(withHint hint: String) {
    Self._validateMemoryLayout
    let result = hint.withCString { hint in
      Library.allTestContentRecords().lazy
        .compactMap { $0.load(withHint: hint) }
        .first
    }
    if let result {
      self = result
    } else {
      return nil
    }
  }

  /// All testing libraries known to the system including Swift Testing.
  @_spi(ForToolsIntegrationOnly)
  public static var all: some Sequence<Self> {
    Self._validateMemoryLayout
    return Library.allTestContentRecords().lazy.compactMap { $0.load() }
  }
}
#endif

// MARK: - Referring to Swift Testing directly

extension Library {
  /// The ABI entry point function for the testing library, thunked so that it
  /// is compatible with the ``Library`` ABI.
  private static let _libraryRecordEntryPoint: Library.EntryPoint = { configurationJSON, configurationJSONByteCount, _, context, recordJSONHandler, completionHandler in
#if !SWT_NO_RUNTIME_LIBRARY_DISCOVERY
    // Capture appropriate state from the arguments to forward into the canonical
    // entry point function.
    let contextBitPattern = UInt(bitPattern: context)
    let configurationJSON = UnsafeRawBufferPointer(start: configurationJSON, count: configurationJSONByteCount)
    var args: __CommandLineArguments_v0
    let eventHandler: Event.Handler
    do {
      args = try JSON.decode(__CommandLineArguments_v0.self, from: configurationJSON)
      eventHandler = try eventHandlerForStreamingEvents(withVersionNumber: args.eventStreamVersionNumber, encodeAsJSONLines: false) { recordJSON in
        let context = UnsafeRawPointer(bitPattern: contextBitPattern)!
        recordJSONHandler(recordJSON.baseAddress!, recordJSON.count, 0, context)
      }
    } catch {
      // TODO: interpret more complex results than a process exit code
      var resultJSON = "\(EXIT_FAILURE)"
      return resultJSON.withUTF8 { resultJSON in
        completionHandler(resultJSON.baseAddress!, resultJSON.count, 0, context)
      }
    }

    // Avoid infinite recursion and double JSON output. (Other libraries don't
    // need to clear these fields.)
    args.testingLibrary = nil
    args.eventStreamOutputPath = nil

    // Create an async context and run tests within it.
    let run = { @Sendable [args] in
      let context = UnsafeRawPointer(bitPattern: contextBitPattern)!
      let exitCode = await Testing.entryPoint(passing: args, eventHandler: eventHandler)
      var resultJSON = "\(exitCode)"
      resultJSON.withUTF8 { resultJSON in
        completionHandler(resultJSON.baseAddress!, resultJSON.count, 0, context)
      }
    }
    
#if !SWT_NO_UNSTRUCTURED_TASKS
    Task.detached { await run() }
#else
    Task.runInline { await run() }
#endif
#else
    // There is no way to call this function without pointer shenanigans because
    // we are not exposing `callEntryPoint()` nor are we emitting a record into
    // the test content section.
    swt_unreachable()
#endif
  }

  /// An instance of this type representing Swift Testing itself.
  public static let swiftTesting: Self = {
    Self(
      rawValue: (
        name: StaticString("Swift Testing").constUTF8CString,
        canonicalHint: StaticString("swift-testing").constUTF8CString,
        entryPoint: _libraryRecordEntryPoint,
        reserved: (0, 0, 0, 0, 0)
      )
    )
  }()
}

#if !SWT_NO_RUNTIME_LIBRARY_DISCOVERY
// MARK: - Our very own library record

private func _libraryRecordAccessor(_ outValue: UnsafeMutableRawPointer, _ type: UnsafeRawPointer, _ hint: UnsafeRawPointer?, _ reserved: UInt) -> CBool {
#if !hasFeature(Embedded)
  // Make sure that the caller supplied the right Swift type. If a testing
  // library is implemented in a language other than Swift, they can either:
  // ignore this argument; or ask the Swift runtime for the type metadata
  // pointer and compare it against the value `type.pointee` (`*type` in C).
  guard type.load(as: Any.Type.self) == Library.self else {
    return false
  }
#endif

  // Check if the name of the testing library the caller wants is equivalent to
  // "Swift Testing", ignoring case and punctuation. (If the caller did not
  // specify a library name, the caller wants records for all libraries.)
  //
  // Other libraries may opt to compare their hint values differently or accept
  // multiple different strings/patterns.
  let hint = hint.map { $0.load(as: UnsafePointer<CChar>.self) }
  if let hint {
    guard let hint = String(validatingCString: hint),
          String(hint.filter(\.isLetter)).lowercased() == "swifttesting" else {
      return false
    }
  }

  // Initialize the provided memory to the (ABI-stable) library structure.
  _ = outValue.initializeMemory(as: Library.self, to: .swiftTesting)

  return true
}

#if objectFormat(MachO)
@section("__DATA_CONST,__swift5_tests")
#elseif objectFormat(ELF) || objectFormat(Wasm)
@section("swift5_tests")
#elseif objectFormat(COFF)
@section(".sw5test$B")
#else
@__testing(warning: "Platform-specific implementation missing: test content section name unavailable")
#endif
@used
private let _libraryRecord: __TestContentRecord = (
  kind: 0x6D61696E, /* 'main' */
  reserved1: 0,
  accessor: _libraryRecordAccessor,
  context: 0,
  reserved2: 0
)
#endif
