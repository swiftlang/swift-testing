//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !hasFeature(Embedded)
/// A helper protocol for ``makeExistential(_:)``.
private protocol _CopierProtocol<Referent> {
  associatedtype Referent

  /// Load the value at this address into an existential box.
  ///
  /// - Returns: The value at this address.
  static func load(from value: Referent) -> Any?
}

/// A helper type for ``makeExistential(_:)``
private struct _Copier<Referent> where Referent: ~Copyable & ~Escapable {}

extension _Copier: _CopierProtocol where Referent: Copyable & Escapable {
  static func load(from value: Referent) -> Any? {
    value
  }
}
#endif

/// Copy a value to an existential box if its type conforms to `Copyable`.
///
/// - Parameters:
///   - value: The value to copy.
///
/// - Returns: A copy of `value` in an existential box, or `nil` if the type of
///   `value` does not conform to `Copyable`.
///
/// When using Embedded Swift, this function always returns `nil`.
#if !hasFeature(Embedded)
@available(_castingWithNonCopyableGenerics, *)
func makeExistential<T>(_ value: borrowing T) -> Any? where T: ~Copyable & ~Escapable {
  if let type = _Copier<T>.self as? any _CopierProtocol<T>.Type {
    return type.load(from: value)
  }
  return nil
}
#else
func makeExistential<T>(_ value: borrowing T) -> Void? where T: ~Copyable & ~Escapable {
  nil
}
#endif
