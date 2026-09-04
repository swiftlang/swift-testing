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
  private var _sequence: any Sequence<Element> & Sendable

  init<S>(_ sequence: S) where S: Sequence<Element> & Sendable {
    _sequence = sequence
  }

  @_disfavoredOverload
  init(_ sequence: any Sequence<Element> & Sendable) {
    _sequence = sequence
  }

  // MARK: - Sequence

  func makeIterator() -> some IteratorProtocol<Element> {
    sequence(state: _sequence.makeIterator()) { $0.next() }
  }

  var underestimatedCount: Int {
    _sequence.underestimatedCount
  }
}
