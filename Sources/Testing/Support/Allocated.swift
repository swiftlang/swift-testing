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
///
/// **Q:** When should I use `T` vs. `Allocated<T>`?
///
/// **A (short):** Whenever the compiler lets you use `T`, use that.
///
/// **A (long):** Move-only values like mutexes and atomics can generally be
///   locally allocated when they are function-local, global, or `static`. If
///   the instance of `T` in question is an instance member of a reference type
///   (a class or actor), you again generally won't need `Allocated`. If,
///   however, you need your instance of `T` to be an instance member of a
///   copyable value type (a structure or enumeration), then it _must_ be boxed
///   with `Allocated` (or something else that moves its storage onto the heap).
final class Allocated<T> where T: ~Copyable {
  /// The underlying value.
  let value: T

  init(_ value: consuming T) {
    self.value = value
  }
}

extension Allocated: Sendable where T: Sendable & ~Copyable {}
