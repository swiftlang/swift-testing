//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_RUNTIME_LIBRARY_DISCOVERY
@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
private import _TestingInternals

private import Foundation // for JSONSerialization

struct `Library tests` {
  @Test func `Find Swift Testing library`() throws {
    let library = try #require(Library(withHint: "SwIfTtEsTiNg"))
    #expect(library.name == "Swift Testing")
    #expect(library.canonicalHint == "swift-testing")
  }

  @Test func `Run mock library`() async throws {
    try await confirmation("(Mock) issue recorded") { issueRecorded in
      let library = try #require(Library(withHint: "mock"))

      var args = __CommandLineArguments_v0()
      args.eventStreamVersionNumber = ABI.v0.versionNumber
      let exitCode = await library.callEntryPoint(passing: args) { recordJSON in
        do {
          let recordJSON = Data(recordJSON)
          let jsonObject = try JSONSerialization.jsonObject(with: recordJSON)
          let record = try #require(jsonObject as? [String: Any])
          if let kind = record["kind"] as? String, let payload = record["payload"] as? [String: Any] {
            if kind == "event", let eventKind = payload["kind"] as? String {
              if eventKind == "issueRecorded" {
                issueRecorded()
              }
            }
          }
        } catch {
          Issue.record(error)
        }
      }
      #expect(exitCode == EXIT_SUCCESS)
    }
  }
}

// MARK: - Fixtures

extension Library {
  private static let _mockRecordEntryPoint: SWTLibraryEntryPoint = { configurationJSON, configurationJSONByteCount, _, context, recordJSONHandler, completionHandler in
    let tests: [[String: Any]] = [
      [
        "kind": "function",
        "name": "mock_test_1",
        "sourceLocation": [
          "fileID": "__C/mock_file.pascal",
          "filePath": "/tmp/mock_file.pascal",
          "_filePath": "/tmp/mock_file.pascal",
          "line": 1,
          "column": 1,
        ],
        "id": "mock_test_1_id",
        "isParameterized": false
      ]
    ]

    let events: [[String: Any]] = [
      [
        "kind": "runStarted",
      ],
      [
        "kind": "testStarted",
        "testID": "mock_test_1_id"
      ],
      [
        "kind": "issueRecorded",
        "testID": "mock_test_1_id",
        "issue": [
          "isKnown": false,
          "sourceLocation": [
            "fileID": "__C/mock_file.pascal",
            "filePath": "/tmp/mock_file.pascal",
            "_filePath": "/tmp/mock_file.pascal",
            "line": 20,
            "column": 1,
          ],
        ]
      ],
      [
        "kind": "testEnded",
        "testID": "mock_test_1_id"
      ],
      [
        "kind": "runEnded",
      ],
    ]

    for var test in tests {
      test = [
        "version": 0,
        "kind": "test",
        "payload": test
      ]
      let json = try! JSONSerialization.data(withJSONObject: test)
      json.withUnsafeBytes { json in
        recordJSONHandler(json.baseAddress!, json.count, 0, context)
      }
    }
    let now1970 = Date().timeIntervalSince1970
    for var (i, event) in events.enumerated() {
      event["instant"] = [
        "absolute": i,
        "since1970": now1970 + Double(i),
      ]
      event = [
        "version": 0,
        "kind": "event",
        "payload": event
      ]
      let json = try! JSONSerialization.data(withJSONObject: event)
      json.withUnsafeBytes { json in
        recordJSONHandler(json.baseAddress!, json.count, 0, context)
      }
    }

    var resultJSON = "0"
    resultJSON.withUTF8 { resultJSON in
      completionHandler(resultJSON.baseAddress!, resultJSON.count, 0, context)
    }
  }

  static let mock: Self = {
    Self(
      rawValue: .init(
        name: StaticString("Mock Testing Library").constUTF8CString,
        canonicalHint: StaticString("mock").constUTF8CString,
        entryPoint: _mockRecordEntryPoint,
        reserved: (0, 0, 0, 0, 0)
      )
    )
  }()
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
private let _mockLibraryRecord: __TestContentRecord = (
  kind: 0x6D61696E, /* 'main' */
  reserved1: 0,
  accessor: _mockLibraryRecordAccessor,
  context: 0,
  reserved2: 0
)

private func _mockLibraryRecordAccessor(_ outValue: UnsafeMutableRawPointer, _ type: UnsafeRawPointer, _ hint: UnsafeRawPointer?, _ reserved: UInt) -> CBool {
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
  if let hint, 0 != strcasecmp(hint, "mock") {
    return false
  }

  // Initialize the provided memory to the (ABI-stable) library structure.
  _ = outValue.initializeMemory(
    as: SWTLibrary.self,
    to: Library.mock.rawValue
  )

  return true
}
#endif
