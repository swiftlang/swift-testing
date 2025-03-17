//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) private import _TestDiscovery
private import _TestingInternals

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public struct TestLibrary: Sendable {
  typealias EntryPoint = @convention(c) (
    _ context: UnsafeRawPointer,
    _ configurationJSON: UnsafeRawPointer?,
    _ configurationJSONByteCount: Int,
    _ recordHandler: @escaping @Sendable @convention(c) (
      _ context: UnsafeRawPointer,
      _ recordJSON: UnsafeRawPointer,
      _ recordJSONByteCount: Int
    ) -> Void,
    _ completionHandler: @escaping @Sendable @convention(c) (
      _ context: UnsafeRawPointer,
      _ result: Result.RawValue,
      _ errorJSON: UnsafeRawPointer?,
      _ errorJSONByteCount: Int
    ) -> Void
  ) -> Void

  enum Record: @unchecked Sendable, DiscoverableAsTestContent {
    case some(
      flags: UInt16,
      reserved1: UInt16,
      reserved2: UInt32,
      name: UnsafePointer<UInt8>,
      copyVersion: (@convention(c) () -> UnsafeMutablePointer<CChar>)?,
      entryPoint: EntryPoint
    )

    fileprivate static var testContentKind: TestContentKind {
      "tlib"
    }
  }

  public enum Result: CInt, Sendable {
    case success = 0
    case failure = 1
    case noTestsFound = 2
  }

  private var _record: Record

  public static var all: some Sequence<Self> {
    Record.allTestContentRecords().lazy
      .compactMap { $0.load() }
      .map { Self(_record: $0) }
  }

  /// The name of this testing library.
  public var name: String {
    switch _record {
    case let .some(_, _, _, name, _, _):
      name.withMemoryRebound(to: CChar.self, capacity: strlen(name)) { name in
        String(validatingCString: name) ?? "<invalid UTF-8>"
      }
    }
  }

  /// The version of this testing library, if available.
  ///
  /// The format of this string is implementation-defined. It may or may not be
  /// a [Semantic Version](https://www.semver.org).
  public var version: String? {
    switch _record {
    case let .some(_, _, _, _, copyVersion, _):
      guard let version = copyVersion?() else {
        return nil
      }
      defer {
        free(version)
      }
      return String(validatingCString: version)
    }
  }

  private var _entryPoint: EntryPoint {
    switch _record {
    case let .some(_, _, _, _, _, entryPoint):
      entryPoint
    }
  }

  public func run(
    configuration: __CommandLineArguments_v0? = nil,
    recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
  ) async throws -> Result {
    struct Context: Sendable {
      var testLibrary: TestLibrary
      var continuation: CheckedContinuation<Result, any Error>
      var recordHandler: @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
    }
    let context = UnsafeMutablePointer<Context>.allocate(capacity: 1)
    defer {
      context.deinitialize(count: 1)
      context.deallocate()
    }

    let configurationJSON: UnsafeRawBufferPointer = try JSON.withEncoding(of: configuration ?? .init()) { configurationJSON in
      configurationJSON
    }
    defer {
      configurationJSON.deallocate()
    }

    return try await withCheckedThrowingContinuation { continuation in
      context.initialize(to: .init(testLibrary: self, continuation: continuation, recordHandler: recordHandler))

      _entryPoint(
        context,
        configurationJSON.baseAddress,
        configurationJSON.count,
        /* recordHandler: */ { context, recordJSON, recordJSONByteCount in
          let context = context.assumingMemoryBound(to: Context.self)
          let recordJSON = UnsafeRawBufferPointer(start: recordJSON, count: recordJSONByteCount)
          context.pointee.recordHandler(recordJSON)
        },
        /* completionHandler: */ { context, result, errorJSON, errorJSONByteCount in
          let context = context.assumingMemoryBound(to: Context.self)
          guard let result = Result(rawValue: result) else {
            let error = SystemError(description: "Testing library '\(context.pointee.testLibrary.name)' reported unexpected result \(result).")
            return context.pointee.continuation.resume(throwing: error)
          }

          if result == .failure, let errorJSON, errorJSONByteCount > 0 {
            let errorJSON = UnsafeRawBufferPointer(start: errorJSON, count: errorJSONByteCount)
            do {
              let error = try JSON.decode(ABI.EncodedError<ABI.v1>.self, from: errorJSON)
              context.pointee.continuation.resume(throwing: error)
            } catch {
              context.pointee.continuation.resume(throwing: error)
            }
          } else {
            context.pointee.continuation.resume(returning: result)
          }
        }
      )
    }
  }
}
