//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABI {
  /// A type implementing the JSON encoding of ``Library`` for the ABI entry
  /// point and event stream output.
  ///
  /// The properties and members of this type are documented in ABI/JSON.md.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  ///
  /// - Warning: Testing libraries are not yet part of the JSON schema.
  struct EncodedLibrary<V>: Sendable where V: ABI.Version {
    /// The human-readable name of the library.
    var name: String

    /// The canonical form of the "hint" to run the testing library's tests at
    /// runtime.
    var canonicalHint: String

    init(encoding library: borrowing Library) {
      name = library.name
      canonicalHint = library.canonicalHint
    }
  }
}

// MARK: - Codable

extension ABI.EncodedLibrary: Codable {}
