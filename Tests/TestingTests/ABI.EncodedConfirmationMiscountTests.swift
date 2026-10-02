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
  @Test func `Encodes expected single element range with equal bounds`() {
    let miscount = ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(encoding: (actual: 1, expected: 10...10))

    #expect(miscount.actual == 1)
    #expect(miscount.expected.min == 10)
    #expect(miscount.expected.max == 10)
  }

  @Test func `Preserves a range of expected counts`() {
    let miscount = ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(encoding: (actual: 1, expected: 5...10))

    #expect(miscount.actual == 1)
    #expect(miscount.expected.min == 5)
    #expect(miscount.expected.max == 10)
  }

  @Test func `Precondition failure on an unsupported range expression`() async throws {
    await #expect(processExitsWith: .failure) {
      // Unsupported non-integer range
      let _ = ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(
        encoding: (actual: 1, expected: 0.0..<1.5))
    }
  }

  @Test func `Encodes a single expected count as an integer`() throws {
    let miscount = ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(encoding: (actual: 1, expected: 10...10))
    let jsonString = try JSON.encode(miscount)
    #expect(jsonString.contains("\"expected\":10"))
  }

  @Test func `Round-trips a single expected count through JSON`() throws {
    let miscount = ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(encoding: (actual: 1, expected: 10...10))
    let decoded = try JSON.encodeAndDecode(miscount)

    #expect(decoded.actual == 1)
    #expect(decoded.expected.min == 10)
    #expect(decoded.expected.max == 10)
  }

  @Test func `Round-trips a range of expected counts through JSON`() throws {
    let miscount = ABI.EncodedConfirmationMiscount<ABI.CurrentVersion>(encoding: (actual: 1, expected: 5...10))
    let decoded = try JSON.encodeAndDecode(miscount)

    #expect(decoded.actual == 1)
    #expect(decoded.expected.min == 5)
    #expect(decoded.expected.max == 10)
  }
}
#endif
