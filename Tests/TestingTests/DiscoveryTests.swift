//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
@_spi(Experimental) @_spi(ForToolsIntegrationOnly) import _TestDiscovery
#if canImport(Foundation)
private import Foundation
#endif

@Suite("Runtime Test Discovery Tests")
struct DiscoveryTests {
  @Test func testContentKind() {
    let kind1: TestContentKind = "abcd"
    let kind2: TestContentKind = 0x61626364
    #expect(kind1 == kind2)
    #expect(String(describing: kind1) == String(describing: kind2))
    #expect(String(describing: kind1) == "'abcd' (0x61626364)")

    let kind3: TestContentKind = 0xFF123456
    #expect(kind1 != kind3)
    #expect(kind2 != kind3)
    #expect(String(describing: kind1) != String(describing: kind3))
    #expect(String(describing: kind3).lowercased() == "0xff123456")
  }

#if canImport(Foundation)
  @Test func testContentKindCodableConformance() throws {
    let kind1: TestContentKind = "moof"
    let data = try JSONEncoder().encode(kind1)
    let uint32 = try JSONDecoder().decode(UInt32.self, from: data)
    let kind2 = try JSONDecoder().decode(TestContentKind.self, from: data)
    #expect(uint32 == kind2.rawValue)
  }
#endif

  @Test func utf8TestContentKind() {
    let kind: TestContentKind = "\u{1F3B6}"
    #expect(kind.rawValue == 0xF09F8EB6)
    #expect(String(describing: kind).uppercased() == "0XF09F8EB6")
  }

#if !SWT_NO_EXIT_TESTS
  @Test("TestContentKind rejects bad string literals")
  func badTestContentKindLiteral() async {
    await #expect(processExitsWith: .failure) {
      _ = "abc" as TestContentKind
    }
    await #expect(processExitsWith: .failure) {
      _ = "abcde" as TestContentKind
    }
  }
#endif

#if compiler(>=6.3) && !SWT_NO_DYNAMIC_LINKING
  struct MyTestContent: DiscoverableAsTestContent {
    typealias TestContentAccessorHint = UInt32

    var value: UInt32

    static var testContentKind: TestContentKind {
      TestContentKind(rawValue: record.kind)
    }

    static var expectedHint: TestContentAccessorHint {
      0x01020304
    }

    static var expectedValue: UInt32 {
      0xCAFEF00D
    }

    static var expectedContext: UInt {
      record.context
    }

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
    @section("__DATA_CONST,__swift5_tests")
#elseif os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android) || os(WASI)
    @section("swift5_tests")
#elseif os(Windows)
    @section(".sw5test$B")
#else
    @__testing(warning: "Platform-specific implementation missing: test content section name unavailable")
#endif
    @used
    private static let record: __TestContentRecord = (
      0xABCD1234,
      0,
      { outValue, type, hint, _ in
#if !hasFeature(Embedded)
        guard type.load(as: Any.Type.self) == MyTestContent.self else {
          return false
        }
#endif
        if let hint, hint.load(as: TestContentAccessorHint.self) != expectedHint {
          return false
        }
        _ = outValue.initializeMemory(as: Self.self, to: .init(value: expectedValue))
        return true
      },
      0x02040608,
      0
    )
  }

  @Test func testDiscovery() async {
    // Check the type of the test record sequence (it should be lazy.)
    let allRecordsSeq = MyTestContent.allTestContentRecords()
#if SWT_FIXED_143080508
    #expect(allRecordsSeq is any LazySequenceProtocol)
    #expect(!(allRecordsSeq is [TestContentRecord<MyTestContent>]))
#endif

    // It should have exactly one matching record (because we only emitted one.)
    let allRecords = Array(allRecordsSeq)
    #expect(allRecords.count == 1)

    // Can find a single test record
    #expect(allRecords.contains { record in
      record.load()?.value == MyTestContent.expectedValue
      && record.context == MyTestContent.expectedContext
    })

    // Can find a test record with matching hint
    #expect(allRecords.contains { record in
      let hint = MyTestContent.expectedHint
      return record.load(withHint: hint)?.value == MyTestContent.expectedValue
      && record.context == MyTestContent.expectedContext
    })

    // Doesn't find a test record with a mismatched hint
    #expect(!allRecords.contains { record in
      let hint = ~MyTestContent.expectedHint
      return record.load(withHint: hint)?.value == MyTestContent.expectedValue
      && record.context == MyTestContent.expectedContext
    })
  }
#endif
}
