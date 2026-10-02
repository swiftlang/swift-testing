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
    /// A single expected count is a range with equal bounds.
    var expected: ABI.EncodedRange<V>
  }
}

// MARK: - Conversion to/from library types

extension ABI.EncodedConfirmationMiscount {
  /// Encodes a miscount based on the actual and expected count.
  /// - Parameter value: A tuple containing actual and expected number of confirmations.
  ///    If the expected count is a single value, provide it as a single value
  ///    range, e.g. `5...5`.
  init(encoding value: (actual: Int, expected: any RangeExpression)) {
    actual = value.actual
    expected = ABI.EncodedRange<V>(encoding: value.expected)
  }
}

// MARK: - Codable, JSON.Encodable

#if !SWT_NO_CODABLE
extension ABI.EncodedConfirmationMiscount: Codable {
  private enum _CodingKeys: String, CodingKey {
    case actual
    case expected
  }

  func encode(to encoder: any Encoder) throws {
    try encoder.encodeJSONEncodableValue(self)
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: _CodingKeys.self)
    actual = try container.decode(Int.self, forKey: .actual)
    if let count = try? container.decode(Int.self, forKey: .expected) {
      expected = ABI.EncodedRange<V>(encoding: count...count)
    } else {
      expected = try container.decode(ABI.EncodedRange<V>.self, forKey: .expected)
    }
  }
}
#endif

extension ABI.EncodedConfirmationMiscount: JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) -> JSON.Value {
    var result = [String: JSON.Value]()
    result["actual"] = actual.jsonValue(in: context)
    if let min = expected.min, min == expected.max {
      // Single expected count
      result["expected"] = min.jsonValue(in: context)
    } else {
      result["expected"] = expected.jsonValue(in: context)
    }
    return .object(result)
  }
}
#endif
