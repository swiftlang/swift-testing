//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_ABI_JSON_SCHEMA
extension ABI {
  /// A type implementing the JSON encoding of ``TypeInfo`` for the ABI entry
  /// point and event stream output.
  ///
  /// Although ``TypeInfo`` already has a Codable conformance, this structure
  /// provides ABI versioning support. It also allows more optional fields,
  /// which supports type info from non-Swift types.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedTypeInfo<V>: Sendable where V: ABI.Version {
    /// The fully qualified name of the type, if present.
    var fullyQualifiedName: String?

    /// The unqualified name components of the type, if present.
    var unqualifiedName: String?

    /// The mangled name of the type, if present.
    var mangledName: String?

    init(encoding typeInfo: borrowing TypeInfo) {
      fullyQualifiedName = typeInfo.fullyQualifiedName
      unqualifiedName = typeInfo.unqualifiedName
      mangledName = typeInfo.mangledName
    }
  }
}

// MARK: - Codable

extension ABI.EncodedTypeInfo: Codable {}

// MARK: - Conversion to/from library types

extension TypeInfo {
  init<V>(decoding typeInfo: ABI.EncodedTypeInfo<V>) {
    let fullyQualifiedNameComponents =
      typeInfo.fullyQualifiedName
      .map { fullyQualifiedName in
        rawIdentifierAwareSplit(fullyQualifiedName, separator: ".").map(String.init)
      } ?? []

    self.init(
      fullyQualifiedNameComponents: fullyQualifiedNameComponents,
      unqualifiedName: typeInfo.unqualifiedName,
      mangledName: typeInfo.mangledName
    )
  }
}

#endif
