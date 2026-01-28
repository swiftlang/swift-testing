//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// Context for the implementation of ``Array/binarySearch(_:)``.
///
/// This type is declared outside an extension to `Array` because it cannot be
/// generic over `Array.Element`.
private struct _BinarySearchContext {
  var compare: (UnsafeRawPointer?) -> CInt
}

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

  /// Perform a binary search on this array looking for an element that matches
  /// the given predicate function.
  ///
  /// - Parameters:
  ///   - predicate: A predicate function to call. It should return a negative
  ///     number if the instance of `Element` passed to it sorts _before_ the
  ///     desired instance, a positive number if it sorts _after_, and `0` if it
  ///     equals the desired instance.
  ///
  /// - Returns: The first element found that matches `predicate`, or `nil` if
  ///   no matching element is found.
  ///
  /// - Precondition: The array _must_ already be sorted according to
  ///   `predicate`. If it is not sorted, the result is undefined.
  func binarySearch(_ predicate: (borrowing Element) -> Int) -> Element? {
    withoutActuallyEscaping(predicate) { predicate in
      let context = _BinarySearchContext { elementAddress in
        let elementAddress = elementAddress!.assumingMemoryBound(to: Element.self)
        return CInt(clamping: predicate(elementAddress.pointee))
      }
      return withUnsafePointer(to: context) { context in
        self.withUnsafeBufferPointer { elements in
          let result = bsearch(context, elements.baseAddress!, elements.count, MemoryLayout<Element>.stride) { contextAddress, elementAddress in
#if os(Android) || os(FreeBSD)
            let contextAddress = contextAddress as UnsafeRawPointer?
#endif
            let context = contextAddress!.load(as: _BinarySearchContext.self)
            return context.compare(elementAddress)
          }
          return result?.load(as: Element.self)
        }
      }
    }
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
    @_lifetime(borrow self)
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
    @_lifetime(borrow self)
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
