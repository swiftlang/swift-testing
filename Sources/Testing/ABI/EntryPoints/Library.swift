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

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public struct Library: Sendable {
  /* @c */ fileprivate struct Record {
    typealias EntryPoint = @convention(c) (
      _ configurationJSON: UnsafeMutableRawPointer,
      _ configurationJSONByteCount: Int,
      _ reserved: UInt,
      _ context: UnsafeMutableRawPointer,
      _ recordJSONHandler: RecordJSONHandler,
      _ completionHandler: CompletionHandler
    ) -> Void

    typealias RecordJSONHandler = @convention(c) (
      _ recordJSON: UnsafeMutableRawPointer,
      _ recordJSONByteCount: Int,
      _ reserved: UInt,
      _ context: UnsafeMutableRawPointer
    ) -> Void

    typealias CompletionHandler = @convention(c) (
      _ exitCode: CInt,
      _ reserved: UInt,
      _ context: UnsafeMutableRawPointer
    ) -> Void

    nonisolated(unsafe) var name: UnsafePointer<CChar>
    var entryPoint: EntryPoint
    var reserved: UInt
  }

  private var _record: Record

  public var name: String {
    String(validatingCString: _record.name) ?? ""
  }

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
      return EINVAL
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
        _record.entryPoint(
          configurationJSON.baseAddress!,
          configurationJSON.count,
          0,
          context,
          /* recordJSONHandler: */ { recordJSON, recordJSONByteCount, _, context in
            guard let context = Unmanaged<AnyObject>.fromOpaque(context).takeUnretainedValue() as? Context else {
              return
            }
            let recordJSON = UnsafeRawBufferPointer(start: recordJSON, count: recordJSONByteCount)
            context.recordHandler(recordJSON)
          },
          /* completionHandler: */ { exitCode, _, context in
            guard let context = Unmanaged<AnyObject>.fromOpaque(context).takeRetainedValue() as? Context else {
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

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension Library.Record: DiscoverableAsTestContent {
  static var testContentKind: TestContentKind {
    "main"
  }

  typealias TestContentAccessorHint = UnsafePointer<CChar>
}

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension Library {
  public init?(named name: String) {
    let result = name.withCString { name in
      Record.allTestContentRecords().lazy
        .compactMap { $0.load(withHint: name) }
        .map(Self.init(_record:))
        .first
    }
    if let result {
      self = result
    } else {
      return nil
    }
  }

  public static var all: some Sequence<Self> {
    Record.allTestContentRecords().lazy
      .compactMap { $0.load() }
      .map(Self.init(_record:))
  }
}

// MARK: - Our very own entry point

private let testingLibraryDiscoverableEntryPoint: Library.Record.EntryPoint = { configurationJSON, configurationJSONByteCount, _, context, recordJSONHandler, completionHandler in
  do {
    let configurationJSON = UnsafeRawBufferPointer(start: configurationJSON, count: configurationJSONByteCount)
    let args = try JSON.decode(__CommandLineArguments_v0.self, from: configurationJSON)
    let eventHandler = try eventHandlerForStrecamingEvents(withVersionNumber: args.eventStreamVersionNumber, encodeAsJSONLines: false) { recordJSON in
       recordJSONHandler(recordJSON.baseAddress!, recordJSON.count, 0, context)
    }

    Task.detached {
      let exitCode = await Testing.entryPoint(passing: args, eventHandler: eventHandler)
      completionHandler(exitCode, 0, context)
    }
  } catch {
    // TODO: more advanced error recovery?
    return completionHandler(EINVAL, 0, context)
  }
}

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
@_section("__DATA_CONST,__swift5_tests")
#elseif os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android) || os(WASI)
@_section("swift5_tests")
#elseif os(Windows)
@_section(".sw5test$B")
#else
@__testing(warning: "Platform-specific implementation missing: test content section name unavailable")
#endif
@_used
private let testingLibraryRecord: __TestContentRecord = (
  0x6D61696E, /* 'main' */
  0,
  { outValue, type, hint, _ in
#if !hasFeature(Embedded)
    guard type.load(as: Any.Type.self) == Library.Record.self else {
      return false
    }
#endif
    let hint = hint.map { $0.load(as: UnsafePointer<CChar>.self) }
    if let hint {
      guard let hint = String(validatingCString: hint),
            String(hint.filter(\.isLetter)).lowercased() == "swifttesting" else {
        return false
      }
    }
    let name: StaticString = "Swift Testing"
    name.utf8Start.withMemoryRebound(to: CChar.self, capacity: name.utf8CodeUnitCount + 1) { name in
      _ = outValue.initializeMemory(
        as: Library.Record.self,
        to: .init(
          name: name,
          entryPoint: testingLibraryDiscoverableEntryPoint,
          reserved: 0
        )
      )
    }
    return true
  },
  0,
  0
)
