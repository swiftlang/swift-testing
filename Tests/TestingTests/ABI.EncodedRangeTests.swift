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
@Suite struct `ABI.EncodedRange Tests` {
  @Test(arguments: [
    (ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: 1...10), 1 as Int?, 10 as Int?),
    (ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: 1..<10), 1, 9),
    (ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: 1...), 1, nil),
    // The following ranges are NOT supported by confirmation, but are included for completeness.
    (ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: ...10), nil, 10),
    (ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: ..<10), nil, 9),
  ]) func `Encodes a closed range`(range: ABI.EncodedRange<ABI.CurrentVersion>?, min: Int?, max: Int?) throws {
    let range = try #require(range)
    #expect(range.min == min)
    #expect(range.max == max)
  }

  @Test(arguments: [
    ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: 1...10),
    ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: 1..<10),
    ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: 1...),
    ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: ...10),
    ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: ..<10),
  ]) func `Round-trips through JSON`(range: ABI.EncodedRange<ABI.CurrentVersion>?) throws {
    let range = try #require(range)
    let decoded = try JSON.encodeAndDecode(range)
    #expect(decoded.min == range.min)
    #expect(decoded.max == range.max)
  }

  @Test func `Unsupported ranges fail to decode`() {
    #expect(ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: ..<Int.min) == nil)
    #expect(ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: Int.min..<Int.min) == nil)

    // Unsupported non-integer range
    #expect(ABI.EncodedRange<ABI.CurrentVersion>(expectedRange: 0.0..<1.5) == nil)
  }

  @Test(arguments: [
    (1 as Int?, 10 as Int?, 1...10),

    (1, nil, 1...Int.max),
    (1, Int.max, 1...Int.max),

    (nil, 10, Int.min...10),
    (Int.min, 10, Int.min...10),
  ])
  func `EncodedRange -> ClosedRange<Int>`(min: Int?, max: Int?, expected: ClosedRange<Int>) throws {
    let range = try ABI.EncodedRange<ABI.CurrentVersion>.rangeWithBounds(min: min, max: max)
    #expect(ClosedRange<Int>(decoding: range) == expected)
  }
}

extension ABI.EncodedRange {
  /// Construct a range with custom bounds for ease of test setup.
  static func rangeWithBounds(min: Int?, max: Int?) throws -> Self {
    if let min, let max {
      try #require(min <= max)
    }
    var range = try #require(Self(expectedRange: 0...10))
    range.min = min
    range.max = max
    return range
  }
}
#endif
