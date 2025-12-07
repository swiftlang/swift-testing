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
private import _TestingInternals

/// A type representing a testing library such as Swift Testing or XCTest.
@_spi(Experimental)
public struct Library: Sendable {
  /// - Important: The in-memory layout of ``Library`` must _exactly_ match the
  ///   layout of this type. As such, it must not contain any other stored
  ///   properties.
  private nonisolated(unsafe) var _library: SWTLibrary

  fileprivate init(_ library: SWTLibrary) {
    _library = library
  }

  /// The human-readable name of this library.
  ///
  /// For example, the value of this property for an instance of this type that
  /// represents the Swift Testing library is `"Swift Testing"`.
  public var name: String {
    String(validatingCString: _library.name) ?? ""
  }

  /// Call the entry point function of this library.
  @_spi(ForToolsIntegrationOnly)
  public func callEntryPoint(
    passing args: __CommandLineArguments_v0? = nil,
    recordHandler: @escaping @Sendable (
      _ recordJSON: UnsafeRawBufferPointer
    ) -> Void = { _ in }
  ) async -> CInt {
    let configurationJSON: [UInt8]
    do {
      let args = try args ?? parseCommandLineArguments(from: CommandLine.arguments)
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
        _library.entryPoint(
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
  private static let _validateMemoryLayout: Void = {
    assert(MemoryLayout<Library>.size == MemoryLayout<SWTLibrary>.size, "Library.size (\(MemoryLayout<Library>.size)) != SWTLibrary.size (\(MemoryLayout<SWTLibrary>.size)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    assert(MemoryLayout<Library>.stride == MemoryLayout<SWTLibrary>.stride, "Library.stride (\(MemoryLayout<Library>.stride)) != SWTLibrary.stride (\(MemoryLayout<SWTLibrary>.stride)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    assert(MemoryLayout<Library>.alignment == MemoryLayout<SWTLibrary>.alignment, "Library.alignment (\(MemoryLayout<Library>.alignment)) != SWTLibrary.alignment (\(MemoryLayout<SWTLibrary>.alignment)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
  }()

  @_spi(ForToolsIntegrationOnly)
  public init?(named name: String) {
    Self._validateMemoryLayout
    let result = name.withCString { name in
      Library.allTestContentRecords().lazy
        .compactMap { $0.load(withHint: name) }
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

// MARK: - Our very own entry point

private let _discoverableEntryPoint: SWTLibraryEntryPoint = { configurationJSON, configurationJSONByteCount, _, context, recordJSONHandler, completionHandler in
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

  // Avoid infinite recursion. (Other libraries don't need to clear this field.)
  args.testingLibrary = nil

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
}

private func _discoverableAccessor(_ outValue: UnsafeMutableRawPointer, _ type: UnsafeRawPointer, _ hint: UnsafeRawPointer?, _ reserved: UInt) -> CBool {
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
    to: .init(
      name: swt_getSwiftTestingLibraryName(),
      entryPoint: _discoverableEntryPoint,
      reserved: (0, 0, 0, 0, 0, 0)
    )
  )

  return true
}

#if compiler(>=6.3)
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
#else
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
private let testingLibraryRecord: __TestContentRecord = (
  0x6D61696E, /* 'main' */
  0,
  _discoverableAccessor,
  0,
  0
)
