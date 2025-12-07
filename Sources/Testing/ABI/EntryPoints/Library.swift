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
public struct Library: Sendable, BitwiseCopyable {
  /// The underlying instance of ``SWTLibrary``.
  ///
  /// - Important: The in-memory layout of ``Library`` must _exactly_ match the
  ///   layout of this type. As such, it must not contain any other stored
  ///   properties.
  nonisolated(unsafe) var rawValue: SWTLibrary

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
  @_spi(ForToolsIntegrationOnly)
  public func callEntryPoint(
    passing args: __CommandLineArguments_v0? = nil,
    recordHandler: @escaping @Sendable (
      _ recordJSON: UnsafeRawBufferPointer
    ) -> Void = { _ in }
  ) async -> CInt {
    var recordHandler = recordHandler

    let configurationJSON: [UInt8]
    do {
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
          oldRecordHandler(recordJSON)
        }
      }

      configurationJSON = try JSON.withEncoding(of: args) { configurationJSON in
        configurationJSON.withMemoryRebound(to: UInt8.self) { Array($0) }
      }
    } catch {
      // TODO: more advanced error recovery?
      return EXIT_FAILURE
    }

    return await withCheckedContinuation { continuation in
      struct Context {
        var continuation: CheckedContinuation<CInt, Never>
        var recordHandler: @Sendable (UnsafeRawBufferPointer) -> Void
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
            context.recordHandler(recordJSON)
          },
          /* completionHandler: */ { exitCode, _, context in
            guard let context = Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as? Context else {
              return
            }
            context.continuation.resume(returning: exitCode)
          }
        )
      }
    }
  }
#endif
}

#if !SWT_NO_RUNTIME_LIBRARY_DISCOVERY
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
  /// that of ``SWTLibrary``.
  private static let _validateMemoryLayout: Void = {
    assert(MemoryLayout<Library>.size == MemoryLayout<SWTLibrary>.size, "Library.size (\(MemoryLayout<Library>.size)) != SWTLibrary.size (\(MemoryLayout<SWTLibrary>.size)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    assert(MemoryLayout<Library>.stride == MemoryLayout<SWTLibrary>.stride, "Library.stride (\(MemoryLayout<Library>.stride)) != SWTLibrary.stride (\(MemoryLayout<SWTLibrary>.stride)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    assert(MemoryLayout<Library>.alignment == MemoryLayout<SWTLibrary>.alignment, "Library.alignment (\(MemoryLayout<Library>.alignment)) != SWTLibrary.alignment (\(MemoryLayout<SWTLibrary>.alignment)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
  }()

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

  @_spi(ForToolsIntegrationOnly)
  public static var all: some Sequence<Self> {
    Self._validateMemoryLayout
    return Library.allTestContentRecords().lazy.compactMap { $0.load() }
  }
}
#endif

// MARK: - Referring to Swift Testing directly

extension Library {
  /// TheABI  entry point function for the testing library, thunked so that it
  /// is compatible with the ``Library`` ABI.
  private static let _libraryRecordEntryPoint: SWTLibraryEntryPoint = { configurationJSON, configurationJSONByteCount, _, context, recordJSONHandler, completionHandler in
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
      // TODO: more advanced error recovery?
      return completionHandler(EXIT_FAILURE, 0, context)
    }

    // Avoid infinite recursion and double JSON output. (Other libraries don't
    // need to clear these fields.)
    args.testingLibrary = nil
    args.eventStreamOutputPath = nil

    // Create an async context and run tests within it.
#if !SWT_NO_UNSTRUCTURED_TASKS
    Task.detached { [args] in
      let context = UnsafeRawPointer(bitPattern: contextBitPattern)!
      let exitCode = await Testing.entryPoint(passing: args, eventHandler: eventHandler)
      completionHandler(exitCode, 0, context)
    }
#else
    let exitCode = Task.runInline { [args] in
      await Testing.entryPoint(passing: args, eventHandler: eventHandler)
    }
    completionHandler(exitCode, 0, context)
#endif
#else
    // There is no way to call this function without pointer shenanigans because
    // we are not exposing `callEntryPoint()` nor are we emitting a record into
    // the test content section.
    swt_unreachable()
#endif
  }

  /// An instance of this type representing Swift Testing itself.
  static let swiftTesting: Self = {
    Self(
      rawValue: .init(
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
  let hint = hint.map { $0.load(as: UnsafePointer<CChar>.self) }
  if let hint {
    guard let hint = String(validatingCString: hint),
          String(hint.filter(\.isLetter)).lowercased() == "swifttesting" else {
      return false
    }
  }

  // Initialize the provided memory to the (ABI-stable) library structure.
  _ = outValue.initializeMemory(
    as: SWTLibrary.self,
    to: Library.swiftTesting.rawValue
  )

  return true
}

#if compiler(>=6.3) && hasFeature(CompileTimeValuesPreview)
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
@section("__DATA_CONST,__swift5_tests")
#elseif os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android) || os(WASI)
@section("swift5_tests")
#elseif os(Windows)
@section(".sw5test$B")
#else
//@__testing(warning: "Platform-specific implementation missing: test content section name unavailable")
#endif
@used
#elseif hasFeature(SymbolLinkageMarkers)
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
@_section("__DATA_CONST,__swift5_tests")
#elseif os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android) || os(WASI)
@_section("swift5_tests")
#elseif os(Windows)
@_section(".sw5test$B")
#else
//@__testing(warning: "Platform-specific implementation missing: test content section name unavailable")
#endif
@_used
#endif
private let _libraryRecord: __TestContentRecord = (
  kind: 0x6D61696E, /* 'main' */
  reserved1: 0,
  accessor: _libraryRecordAccessor,
  context: 0,
  reserved2: 0
)
#endif
