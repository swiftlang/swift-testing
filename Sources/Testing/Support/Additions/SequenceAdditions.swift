//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that acts much like `AnySequence` from the standard library, but
/// which is sendable and requires its underlying sequence to be sendable too.
struct AnySendableSequence<Element>: Sendable, Sequence where Element: Sendable {
#if !hasFeature(Embedded) || (SWT_FIXED_186615041 && SWT_FIXED_186684136)
  /// The underlying sequence.
  private var _sequence: any Sequence<Element> & Sendable
#else
  /// A projection of the underlying sequence's `makeIterator()` function.
  private var _makeIterator: @Sendable () -> AnyIterator<Element>
#endif

  init<S>(_ sequence: S) where S: Sequence<Element> & Sendable {
#if !hasFeature(Embedded) || (SWT_FIXED_186615041 && SWT_FIXED_186684136)
    _sequence = sequence
#else
    _makeIterator = { AnyIterator(sequence.makeIterator()) }
#endif
    underestimatedCount = sequence.underestimatedCount
  }

  // MARK: - Sequence

  func makeIterator() -> some IteratorProtocol<Element> {
#if !hasFeature(Embedded) || (SWT_FIXED_186615041 && SWT_FIXED_186684136)
    let iterator = _sequence.makeIterator()
    return AnyIterator(iterator)
#else
    _makeIterator()
#endif
  }

  private(set) var underestimatedCount: Int
}
