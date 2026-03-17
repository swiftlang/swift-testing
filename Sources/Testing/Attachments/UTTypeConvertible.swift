//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && !hasFeature(Embedded) && canImport(UniformTypeIdentifiers)
private import _TestingInternals

/// A protocol describing types that can be converted to and from instances of
/// [`UTType`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct).
///
/// You do not need to add additional conformances to this protocol. If you want
/// to implement the `_preferredContentType(for:)` function in a type that
/// conforms to ``Attachable``, it should return an instance of [`UTType`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct)
/// or return `nil`.
package protocol UTTypeConvertible: Sendable {
  /// Initialize an instance of this type from the given uniform type
  /// identifier.
  ///
  /// If the given uniform type identifier is invalid, this initializer returns
  /// `nil`.
  init?(_ identifier: String)

  /// This instance's corresponding uniform type identifier.
  var identifier: String { get }
}

/// A type that stands in for an instance of another type that conforms to
/// ``UTTypeConvertible``.
package struct UTTypeProxy: Sendable, UTTypeConvertible {
  // An enumeration describing the kinds of proxied type.
  private enum _Kind {
    /// An entire instance of some type conforming to ``UTTypeConvertible``.
    case wrappedType(any UTTypeConvertible)

    /// Only a uniform type identifier is available.
    case identifierOnly(String)
  }

  /// What this instance is proxying.
  private var _kind: _Kind

  package init?(_ type: some UTTypeConvertible) {
    _kind = .wrappedType(type)
  }

  /// The underlying Swift value, conforming to ``UTTypeConvertible``, proxied
  /// by this instance (if any).
  package var wrappedType: (any UTTypeConvertible)? {
    guard case let .wrappedType(contentType) = _kind else {
      return nil
    }
    if let contentType = contentType as? UTTypeProxy,
       let wrappedType = contentType.wrappedType {
      // We're recursively wrapping a proxied content type.
      return wrappedType
    }
    return contentType
  }

  package init?(_ identifier: String) {
    _kind = .identifierOnly(identifier)
  }

  package var identifier: String {
    switch _kind {
    case let .wrappedType(contentType):
      contentType.identifier
    case let .identifierOnly(identifier):
      identifier
    }
  }
}
#endif
