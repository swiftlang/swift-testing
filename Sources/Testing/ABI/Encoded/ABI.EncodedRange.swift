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
  /// A type implementing the JSON encoding of a range for the ABI entry point
  /// and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedRange<V>: Sendable where V: ABI.Version {
    /// The inclusive lower bound of the range, if any.
    var min: Int?

    /// The inclusive upper bound of the range, if any.
    var max: Int?

    // Creates the encoded range from an expected confirmation count.
    //
    // Returns nil if the range could not be represented by an inclusive upper
    // bound (e.g. `..<Int.min`), or if the range was not a supported
    // integer-valued range.
    //
    // For completeness, this supports a superset of ranges allowed by the
    // Testing library for confirmations. For example,
    // `confirmation(expectedCount:...10)` without a explicit lower bound is
    // considered ambiguous, but can be represented as an encoded range with a
    // nil `min`.
    init?(expectedRange: any RangeExpression) {
      if let range = expectedRange as? ClosedRange<Int> {
        min = range.lowerBound
        max = range.upperBound
      } else if let range = expectedRange as? Range<Int> {
        guard range.upperBound > Int.min else { return nil }
        min = range.lowerBound
        max = range.upperBound - 1
      } else if let range = expectedRange as? PartialRangeFrom<Int> {
        min = range.lowerBound
      } else if let range = expectedRange as? PartialRangeUpTo<Int> {
        guard range.upperBound > Int.min else { return nil }
        max = range.upperBound - 1
      } else if let range = expectedRange as? PartialRangeThrough<Int> {
        max = range.upperBound
      } else {
        return nil
      }
    }
  }
}

// MARK: - Codable

extension ABI.EncodedRange: Codable {}

// MARK: - Conversion to/from library types

extension ClosedRange<Int> {
  init<V>(decoding value: ABI.EncodedRange<V>) {
    let min = value.min ?? Int.min
    let max = value.max ?? Int.max
    precondition(min <= max)

    self.init(uncheckedBounds: (min, max))
  }
}

#endif
