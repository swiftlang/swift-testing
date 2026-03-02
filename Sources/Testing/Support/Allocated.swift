//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A class that provides heap-allocated storage for a move-only value.
///
/// Use this class when you have a move-only value such as an instance of
/// ``Mutex`` that you need to store in an aggregate value type such as a
/// copyable structure.
final class Allocated<T> where T: ~Copyable {
  /// The underlying value.
  let value: T

  init(_ value: consuming T) {
    self.value = value
  }
}

extension Allocated: Sendable where T: Sendable & ~Copyable {}
