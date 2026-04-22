//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) import Testing
#if canImport(Foundation)
import Foundation
#endif

@Suite("SkipInfo Tests")
struct SkipInfoTests {
  @Test("comment property") func comment() {
    var skipInfo = SkipInfo(comment: "abc123", sourceContext: .init())
    #expect(skipInfo.comment == "abc123")
    skipInfo.comment = .__line("// Foo")
    #expect(skipInfo.comment == .__line("// Foo"))
  }

  @Test("sourceLocation property") func sourceLocation() {
    let sourceLocation1 = #_sourceLocation
    var skipInfo = SkipInfo(sourceContext: .init(sourceLocation: sourceLocation1))
    #expect(skipInfo.sourceLocation == sourceLocation1)

    let sourceLocation2 = #_sourceLocation
    skipInfo.sourceLocation = sourceLocation2
    #expect(skipInfo.sourceLocation == sourceLocation2)
  }

#if canImport(Foundation)
  @Test(
    "Decode from event",
    arguments: [
      "testCancelled",
      "testCaseCancelled",
      "testSkipped",
    ]
  ) func roundTrip(kind: String) throws {
    var json = #"""
      {
        "kind": "\#(kind)",
        "instant": { "since1970": 0, "absolute": 0 },
        "messages": [],
        "_comments": ["Skipped Test"],
        "_sourceLocation": { "filePath": "/a/b/c", "line": 12345, "column": 67890 },
      }
      """#
    let event = try json.withUTF8 { json in
      try JSON.decode(ABI.EncodedEvent<ABI.CurrentVersion>.self, from: UnsafeRawBufferPointer(json))
    }

    let info = SkipInfo(decoding: event)
    let expected = SkipInfo(
      comment: "Skipped Test",
      sourceContext: .init(backtrace: nil, sourceLocation: .init(SourceLocation(fileIDSynthesizingIfNeeded: nil, filePath: "/a/b/c", line: 12345, column: 67890))))
    #expect(info == expected)
  }

  @Test("SkipInfo nil for unsupported event kind") func decodeSkipInfoUnsupported() throws {
    var json = #"""
      {
        "kind": "testStarted",
        "instant": { "since1970": 0, "absolute": 0 },
        "messages": [],
        "_comments": ["Skipped Test"],
        "_sourceLocation": { "filePath": "/a/b/c", "line": 12345, "column": 67890 },
      }
      """#
    let event = try json.withUTF8 { json in
      try JSON.decode(ABI.EncodedEvent<ABI.CurrentVersion>.self, from: UnsafeRawBufferPointer(json))
    }

    let info = SkipInfo(decoding: event)
    #expect(info == nil)
  }
#endif
}
