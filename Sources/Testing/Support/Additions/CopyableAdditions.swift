//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !hasFeature(Embedded)
/// A helper protocol for ``makeExistential(_:)``.
private protocol _CopierProtocol<Referent> {
  /// The type of value that a conforming type can copy.
  associatedtype Referent

  /// Cast the given value to `Any`.
  ///
  /// - Parameters:
  ///   - value: The value to cast.
  ///
  /// - Returns: `value` cast to `Any`.
  static func cast(_ value: Referent) -> Any
}

/// A helper type for ``makeExistential(_:)``
private struct _Copier<Referent> where Referent: ~Copyable & ~Escapable {}

extension _Copier: _CopierProtocol where Referent: Copyable & Escapable {
  static func cast(_ value: Referent) -> Any {
    value
  }
}
#endif

/// Copy a value to an existential box if its type conforms to `Copyable` and
/// `Escapable`.
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
    return type.cast(value)
  }
  return nil
}
#else
func makeExistential<T>(_ value: borrowing T) -> Void? where T: ~Copyable & ~Escapable {
  nil
}
#endif
