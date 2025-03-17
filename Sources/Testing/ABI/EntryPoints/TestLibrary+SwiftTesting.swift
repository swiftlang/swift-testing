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

#if hasFeature(SymbolLinkageMarkers)
private let _copyVersion: @convention(c) () -> UnsafeMutablePointer<CChar> = {
  strdup(swt_getTestingLibraryVersion())
}

private let _entryPoint: TestLibrary.EntryPoint = { context, configurationJSON, configurationJSONByteCount, recordHandler, completionHandler in
  do {
    let configurationJSON = UnsafeRawBufferPointer(start: configurationJSON, count: configurationJSONByteCount)
    let args = try JSON.decode(__CommandLineArguments_v0.self, from: configurationJSON)
    nonisolated(unsafe) let context = context
    let eventHandler = ABI.v1.eventHandler(encodeAsJSONLines: true) { recordJSON in
      recordHandler(context, recordJSON.baseAddress!, recordJSON.count)
    }
    Task {
      await entryPoint(passing: args, eventHandler: eventHandler)
    }
  } catch {
    let error = ABI.EncodedError<ABI.v1>(encoding: error)
    return try! JSON.withEncoding(of: error) { errorJSON in
      completionHandler(context, TestLibrary.Result.failure.rawValue, errorJSON.baseAddress, errorJSON.count)
    }
  }
}

private let _store: __TestContentRecordAccessor = { outValue, _, hint, _ in
  outValue.withMemoryRebound(to: TestLibrary.Record.self, capacity: 1) { outValue in
    outValue.initialize(
      to: .some(
        flags: 0b0001,
        reserved1: 0,
        reserved2: 0,
        name: ("Swift Testing" as StaticString).utf8Start,
        copyVersion: _copyVersion,
        entryPoint: _entryPoint
      )
    )
    return true
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
private let _testLibrary: __TestContentRecord = (
  kind: 0x746C6962,
  reserved1: 0,
  accessor: _store,
  context: 0,
  reserved2: 0
)
#endif

