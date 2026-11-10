//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Span where Element: Equatable {
  /// Test whether the span contains an element matching a predicate function.
  ///
  /// - Parameters:
  ///   - predicate: The predicate function with which to compare elements.
  ///
  /// - Returns: Whether or not this span contains some element `e` where the
  ///   expression `predicate(e)` equals `true`.
  func contains(where predicate: (Element) -> Bool) -> Bool {
    withUnsafeBufferPointer { buffer in
      unsafe buffer.contains(where: predicate)
    }
  }
}

// MARK: -

extension ContiguousArray {
  /// Construct a contiguous array from a span.
  ///
  /// - Parameters:
  ///   - span: The span to construct the array from. The elements of this span
  ///     are copied into the result.
  init(_ span: Span<Element>) {
    self = unsafe span.withUnsafeBufferPointer(Self.init)
  }

  /// Append a span to this contiguous array.
  ///
  /// - Parameters:
  ///   - span: The span to append to `self`.
  mutating func append(contentsOf span: Span<Element>) {
    span.withUnsafeBufferPointer { unsafe self.append(contentsOf: $0) }
  }
}

// MARK: -

extension String {
  /// Create a string by decoding the given Unicode span.
  ///
  /// - Parameters:
  ///   - span: The span to decode. This span must contain valid Unicode code
  ///     points encoded as `unicodeEncoding`.
  ///   - unicodeEncoding: The Unicode encoding used to encode `span`.
  init<U>(decoding span: Span<U.CodeUnit>, as unicodeEncoding: U.Type) where U: Unicode.Encoding {
    self = span.withUnsafeBufferPointer { unsafe Self(decoding: $0, as: unicodeEncoding) }
  }
}
