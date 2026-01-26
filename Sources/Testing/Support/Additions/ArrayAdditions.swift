//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Array {
  /// Initialize an array from a single optional value.
  ///
  /// - Parameters:
  ///   - optionalValue: The value to place in the array.
  ///
  /// If `optionalValue` is not `nil`, it is unwrapped and the resulting array
  /// contains a single element equal to its value. If `optionalValue` is `nil`,
  /// the resulting array is empty.
  init(_ optionalValue: Element?) {
    self = optionalValue.map { [$0] } ?? []
  }
}

// MARK: - Span/RawSpan support

extension Array where Element == UInt8 {
  init(_ bytes: borrowing RawSpan) {
    self = bytes.withUnsafeBytes { Array($0) }
  }
}

#if SWT_TARGET_OS_APPLE
extension Array {
  /// The elements of this array as a span.
  ///
  /// This property is equivalent to the `span` property in the Swift standard
  /// library, but is available on earlier Apple platforms.
  var span: Span<Element> {
    _read {
      let slice = self[...]
      yield slice.span
    }
  }
}

extension String.UTF8View {
  /// A raw span representing this string as UTF-8, not including a trailing
  /// null character.
  ///
  /// This property is equivalent to the `span` property in the Swift standard
  /// library, but is available on earlier Apple platforms.
  var span: Span<Element> {
    _read {
      // This implementation incurs a copy even for native Swift strings. This
      // isn't currently a hot path in the testing library though.
      yield ContiguousArray(self).span
    }
  }
}
#endif

// MARK: - Parameter pack additions

/// Get the number of elements in a parameter pack.
///
/// - Parameters:
///   - pack: The parameter pack.
///
/// - Returns: The number of elements in `pack`.
///
/// - Complexity: O(_n_) where _n_ is the number of elements in `pack`. The
///   compiler may be able to optimize this operation when the types of `pack`
///   are statically known.
func parameterPackCount<each T>(_ pack: repeat each T) -> Int {
  var result = 0
  for _ in repeat each pack {
    result += 1
  }
  return result
}
