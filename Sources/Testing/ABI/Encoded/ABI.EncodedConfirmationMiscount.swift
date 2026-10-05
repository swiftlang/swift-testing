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
    /// A single expected count is a single-valued range.
    var expected: any RangeExpression & Sendable
  }
}

// MARK: - Conversion to/from library types

extension ABI.EncodedConfirmationMiscount {
  /// Encodes a miscount based on the actual and expected count.
  /// - Parameter value: A tuple containing actual and expected number of confirmations.
  ///    If the expected count is a single value, provide it as a single value
  ///    range, e.g. `5...5`.
  init(encoding value: (actual: Int, expected: any RangeExpression & Sendable)) {
    actual = value.actual
    expected = value.expected
  }
}

// MARK: - Codable, JSON.Encodable

#if !SWT_NO_CODABLE
extension ABI.EncodedConfirmationMiscount: Codable {
  private enum _CodingKeys: String, CodingKey {
    case actual
    case expected
  }

  /// The coding keys for an expected range encoded as an object.
  private enum _RangeCodingKeys: String, CodingKey {
    /// The inclusive lower bound of the range, if any.
    case min

    /// The inclusive upper bound of the range, if any.
    case max
  }

  func encode(to encoder: any Encoder) throws {
    try encoder.encodeJSONEncodableValue(self)
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: _CodingKeys.self)
    actual = try container.decode(Int.self, forKey: .actual)

    // Attempt to decode a single-valued expected count,
    // then fallback to a range count.
    if let count = try? container.decode(Int.self, forKey: .expected) {
      expected = count...count
    } else {
      let rangeContainer = try container.nestedContainer(
        keyedBy: _RangeCodingKeys.self, forKey: .expected)
      let min = try rangeContainer.decodeIfPresent(Int.self, forKey: .min)
      let max = try rangeContainer.decodeIfPresent(Int.self, forKey: .max)
      switch (min, max) {
      case (let min?, let max?):
        guard min <= max else {
          throw DecodingError.dataCorruptedError(
            forKey: .expected, in: container,
            debugDescription: "Expected range lower bound \(min) cannot exceed upper bound \(max)")
        }
        expected = min...max
      case (let min?, nil):
        expected = min...
      case (nil, let max?):
        expected = ...max
      case (nil, nil):
        throw DecodingError.dataCorruptedError(
          forKey: .expected,
          in: container,
          debugDescription: "Expected range must have a lower bound, an upper bound, or both."
        )
      }
    }
  }
}
#endif

extension ABI.EncodedConfirmationMiscount: JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) throws(JSON.EncodingError)
    -> JSON.Value
  {
    var result = [String: JSON.Value]()
    result["actual"] = actual.jsonValue(in: context)

    // Encode a single value as an integer, otherwise as a
    // expected count:
    // 5 -> "expected": 5
    // 1...5 -> "expected": { "min": 1, "max": 5 }
    let (min, max) = try _expectedRangeBounds()
    if let min, min == max {
      result["expected"] = min.jsonValue(in: context)
    } else {
      result["expected"] = _rangeJSON(min: min, max: max, in: context)
    }
    return .object(result)
  }

  /// Create a JSON structure representing the range bounds.
  private func _rangeJSON(min: Int?, max: Int?, in context: borrowing JSON.EncodingContext)
    -> JSON.Value
  {
    var range = [String: JSON.Value]()
    if let min {
      range["min"] = min.jsonValue(in: context)
    }
    if let max {
      range["max"] = max.jsonValue(in: context)
    }
    return .object(range)
  }

  /// Retrieve the inclusive bounds of the expected range. This is done by
  /// attempting to cast the range to a concrete known range type.
  ///
  /// - Throws: If the expected range is of an unsupported type or cannot be
  /// represented as an inclusive bound.
  private func _expectedRangeBounds() throws(JSON.EncodingError) -> (min: Int?, max: Int?) {
    switch expected {
    case let range as ClosedRange<Int>:
      return (range.lowerBound, range.upperBound)
    case let range as Range<Int>:
      guard range.upperBound > Int.min else {
        throw JSON.EncodingError(
          description: "Could not convert a range where upper bound is Int.min: \(range)")
      }
      return (range.lowerBound, range.upperBound - 1)
    case let range as PartialRangeFrom<Int>:
      return (range.lowerBound, nil)
    case let range as PartialRangeUpTo<Int>:
      guard range.upperBound > Int.min else {
        throw JSON.EncodingError(
          description:
            "Could not convert an exclusive partial range where upper bound is Int.min: \(range)")
      }
      return (nil, range.upperBound - 1)
    case let range as PartialRangeThrough<Int>:
      return (nil, range.upperBound)
    default:
      throw JSON.EncodingError(
        description: "Could not convert an unsupported range: \(expected)")
    }
  }
}
#endif
