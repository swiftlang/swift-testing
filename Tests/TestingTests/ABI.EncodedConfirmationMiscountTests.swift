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
  struct `JSON Encoding` {}
  struct `JSON Decoding` {}
  struct `Unsupported Ranges` {}
}

extension `ABI.EncodedConfirmationMiscount Tests`.`JSON Encoding` {
  @Test(arguments: [
    (10...10 as any RangeExpression<Int> & Sendable, #""expected":10"#),
    (10..<11, #""expected":10"#),

    (1...10, #""expected":{"max":10,"min":1}"#),
    (1..<10, #""expected":{"max":9,"min":1}"#),
    (1..., #""expected":{"min":1}"#),

    // The following ranges are NOT supported by confirmation because the lower
    // bound must always be specified, but are included for completeness.
    (...10, #""expected":{"max":10}"#),
    (..<10, #""expected":{"max":9}"#),
  ]) func `Encodes expected counts and round trips through JSON`(
    range: any RangeExpression<Int> & Sendable, expectedRangeJSON: String
  ) throws {
    let miscount = ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(
      encoding: (actual: 1, expected: range))

    let json = try JSON.encode(miscount)
    let expectedConfirmationJSON = #"{"actual":1,\#(expectedRangeJSON)}"#
    #expect(json == expectedConfirmationJSON)

    let decoded = try JSON.encodeAndDecode(miscount)
    #expect(decoded.actual == 1)
    #expect(try JSON.encode(decoded) == json)
  }

  @Test func `Round-trips a single expected count through JSON`() throws {
    let range = 10...10
    let miscount = ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(
      encoding: (actual: 1, expected: range))
    let decoded = try JSON.encodeAndDecode(miscount)

    #expect(decoded.actual == 1)
    #expect(decoded.expected as? ClosedRange<Int> == 10...10)
  }
}

extension `ABI.EncodedConfirmationMiscount Tests`.`JSON Decoding` {
  @Test func `Decodes a range with only a lower bound`() throws {
    let json = #"{"actual":1,"expected":{"min":3}}"#
    let decoded = try JSON.decode(
      ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>.self, from: json)
    #expect((decoded.expected as? PartialRangeFrom<Int>)?.lowerBound == 3)
  }

  @Test func `Decodes a range with only an upper bound`() throws {
    let json = #"{"actual":1,"expected":{"max":10}}"#
    let decoded = try JSON.decode(
      ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>.self, from: json)
    #expect((decoded.expected as? PartialRangeThrough<Int>)?.upperBound == 10)
  }
}

extension `ABI.EncodedConfirmationMiscount Tests`.`Unsupported Ranges` {
  @Test(arguments: [
    // Empty exclusive range
    ..<Int.min as any RangeExpression & Sendable,
    Int.min..<Int.min,

    // Non-integer range
    0.5..<10.5,
    0.5...10.5,
    0.5...,
    ..<10.5,
  ]) func `Throws when encoding an unsupported range`(
    range: any RangeExpression & Sendable
  ) {
    #expect(throws: JSON.EncodingError.self) {
      let miscount = try ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(
        encoding: (actual: 1, expected: range))
      _ = try JSON.encode(miscount)
    }
  }

  @Test func `Throws when encoding an unsupported range expression`() {
    struct UnsupportedRange: RangeExpression, Sendable {
      func relative<C>(to collection: C) -> Range<Int> where C: Collection, Int == C.Index {
        preconditionFailure("Unimplemented")
      }

      func contains(_ element: Int) -> Bool {
        preconditionFailure("Unimplemented")
      }
    }

    #expect(throws: JSON.EncodingError.self) {
      let range = UnsupportedRange()
      let miscount = ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(
        encoding: (actual: 1, expected: range))
      _ = try JSON.encode(miscount)
    }
  }

  @Test(arguments: [
    #"{"actual":1,"expected":{}}"#,
    #"{"actual":1,"expected":{"min":15,"max":10}}"#,
    #"{"actual":1,"expected":{"min":0.5,"max":10.5}}"#,
  ]) func `Throws when decoding an invalid range`(json: String) {
    #expect(throws: DecodingError.self) {
      _ = try JSON.decode(
        ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>.self, from: json)
    }
  }
}

#endif
