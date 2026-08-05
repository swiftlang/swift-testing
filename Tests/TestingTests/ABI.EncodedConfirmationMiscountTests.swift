//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

#if !SWT_NO_ABI_JSON_SCHEMA
@Suite struct `ABI.EncodedConfirmationMiscount Tests` {
  @Test func `Collapses expected single element range to a single count`() throws {
    let miscount = try #require(ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(encoding: (actual: 1, expected: 10...10)))

    #expect(miscount.actual == 1)
    guard case let .single(expected) = miscount.expected else {
      Issue.record("Expected .single case, got \(miscount.expected)")
      return
    }
    #expect(expected == 10)
  }

  @Test func `Preserves a range of expected counts`() throws {
    let miscount = try #require(ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(encoding: (actual: 1, expected: 5...10)))

    #expect(miscount.actual == 1)
    guard case let .range(range) = miscount.expected else {
      Issue.record("Expected .range case, got \(miscount.expected)")
      return
    }
    #expect(range.min == 5)
    #expect(range.max == 10)
  }

  @Test func `Encodes a single expected count as an integer`() throws {
    let miscount = try #require(ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(encoding: (actual: 1, expected: 10...10)))
    try JSON.withEncoding(of: miscount) { json in
      let jsonString = String(decoding: json, as: UTF8.self)
      #expect(jsonString.contains("\"expected\":10"))
    }
  }

  @Test func `Round-trips a single expected count through JSON`() throws {
    let miscount = try #require(ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(encoding: (actual: 1, expected: 10...10)))
    let decoded = try JSON.encodeAndDecode(miscount)

    #expect(decoded.actual == 1)
    guard case let .single(expected) = decoded.expected else {
      Issue.record("Expected .single case, got \(decoded.expected)")
      return
    }
    #expect(expected == 10)
  }

  @Test func `Round-trips a range of expected counts through JSON`() throws {
    let miscount = try #require(ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(encoding: (actual: 1, expected: 5...10)))
    let decoded = try JSON.encodeAndDecode(miscount)

    #expect(decoded.actual == 1)
    guard case let .range(range) = decoded.expected else {
      Issue.record("Expected .range case, got \(decoded.expected)")
      return
    }
    #expect(range.min == 5)
    #expect(range.max == 10)
  }
}
#endif
