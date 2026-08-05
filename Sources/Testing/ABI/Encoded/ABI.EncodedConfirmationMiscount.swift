//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_ABI_JSON_SCHEMA
extension ABI {
  /// A type implementing the JSON encoding of the actual and expected
  /// confirmation counts for a miscounted confirmation for the ABI entry point
  /// and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedConfirmationMiscount<V>: Sendable where V: ABI.Version {
    /// The actual number of confirmations that occurred.
    var actual: Int

    /// The number of confirmations that were expected.
    var expected: ExpectedCount

    /// An enumeration describing the number of confirmations that were
    /// expected, which may be a single value or a range of values.
    enum ExpectedCount {
      /// The expected count was a single value.
      case single(Int)

      /// The expected count was a range of values.
      case range(ABI.EncodedRange<V>)
    }
  }
}

// MARK: - Conversion to/from library types

extension ABI.EncodedConfirmationMiscount {
  /// Encodes a miscount based on the actual and expected count.
  /// - Parameter value: A tuple containing actual and expected number of confirmations.
  ///    If the expected count is a single value, provide it as a single value
  ///    range, e.g. `5...5`.
  init?(encoding value: (actual: Int, expected: any RangeExpression)) {
    guard let range = ABI.EncodedRange<V>(expectedRange: value.expected) else { return nil }

    actual = value.actual
    if let min = range.min, let max = range.max, min == max {
      expected = .single(min)
    } else {
      expected = .range(range)
    }
  }
}

// MARK: - Codable

extension ABI.EncodedConfirmationMiscount: Codable {
  private enum _CodingKeys: String, CodingKey {
    case actual
    case expected
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: _CodingKeys.self)
    try container.encode(actual, forKey: .actual)
    switch expected {
    case .single(let count):
      try container.encode(count, forKey: .expected)
    case .range(let range):
      try container.encode(range, forKey: .expected)
    }
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: _CodingKeys.self)
    actual = try container.decode(Int.self, forKey: .actual)
    if let count = try? container.decode(Int.self, forKey: .expected) {
      expected = .single(count)
    } else {
      expected = .range(try container.decode(ABI.EncodedRange<V>.self, forKey: .expected))
    }
  }
}
#endif
