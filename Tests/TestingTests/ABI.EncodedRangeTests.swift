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
    (ABI.EncodedRange<ABI.CurrentVersion>(encoding: 1...10), 1 as Int?, 10 as Int?),
    (ABI.EncodedRange<ABI.CurrentVersion>(encoding: 1..<10), 1, 9),
    (ABI.EncodedRange<ABI.CurrentVersion>(encoding: 1...), 1, nil),
    // The following ranges are NOT supported by confirmation because the lower
    // bound must always be specified, but are included for completeness.
    (ABI.EncodedRange<ABI.CurrentVersion>(encoding: ...10), nil, 10),
    (ABI.EncodedRange<ABI.CurrentVersion>(encoding: ..<10), nil, 9),
  ]) func `Encodes a closed range`(
    range: ABI.EncodedRange<ABI.CurrentVersion>, min: Int?, max: Int?
  ) throws {
    #expect(range.min == min)
    #expect(range.max == max)
  }

  @Test(arguments: [
    ABI.EncodedRange<ABI.CurrentVersion>(encoding: 1...10),
    ABI.EncodedRange<ABI.CurrentVersion>(encoding: 1..<10),
    ABI.EncodedRange<ABI.CurrentVersion>(encoding: 1...),
    ABI.EncodedRange<ABI.CurrentVersion>(encoding: ...10),
    ABI.EncodedRange<ABI.CurrentVersion>(encoding: ..<10),
  ]) func `Round-trips through JSON`(range: ABI.EncodedRange<ABI.CurrentVersion>) throws {
    let decoded = try JSON.encodeAndDecode(range)
    #expect(decoded.min == range.min)
    #expect(decoded.max == range.max)
  }

#if !SWT_NO_EXIT_TESTS
  @Test func `Empty ranges precondition fail on encoding`() async throws {
    await #expect(processExitsWith: .failure) {
      _ = ABI.EncodedRange<ABI.CurrentVersion>(encoding: ..<Int.min)
    }

    await #expect(processExitsWith: .failure) {
      _ = ABI.EncodedRange<ABI.CurrentVersion>(encoding: Int.min..<Int.min)
    }
  }

  @Test func `Unsupported ranges precondition fail on encoding`() async throws {
    await #expect(processExitsWith: .failure) {
      // Unsupported non-integer range
      _ = ABI.EncodedRange<ABI.CurrentVersion>(encoding: 0.0..<1.5)
    }
  }
#endif

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
    var range = Self(encoding: 0...10)
    range.min = min
    range.max = max
    return range
  }
}
#endif
