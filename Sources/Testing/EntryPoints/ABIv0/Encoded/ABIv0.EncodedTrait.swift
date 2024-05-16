//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABIv0 {
  /// A type implementing the JSON encoding of ``Trait`` for the ABI entry point
  /// and event stream output.
  ///
  /// The properties and members of this type are documented in ABI/JSON.md.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedTrait: Sendable {
    /// An enumeration describing the various kinds of trait that support
    /// encoding as JSON.
    enum Kind: Sendable {
      /// An instance of ``Bug``.
      case bug(Bug)

      /// An instance of ``Tag``.
      ///
      /// Note that this case corresponds to a single tag, not an instance of
      /// ``Tag/List``.
      case tag(Tag)
    }

    /// The kind of trait.
    var kind: Kind

    init(encoding bug: borrowing Bug) {
      kind = .bug(copy bug)
    }

    init(encoding tag: borrowing Tag) {
      kind = .tag(copy tag)
    }
  }
}

// MARK: - Codable

extension ABIv0.EncodedTrait: Codable {
  private enum CodingKeys: String, CodingKey {
    case kind
    case payload
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch kind {
    case let .bug(bug):
      try container.encode("bug", forKey: .kind)
      try container.encode(bug, forKey: .payload)
    case let .tag(tag):
      try container.encode("tag", forKey: .kind)
      try container.encode(tag, forKey: .payload)
    }
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    kind = switch try container.decode(String.self, forKey: .kind) {
    case "bug":
      try .bug(container.decode(Bug.self, forKey: .payload))
    case "tag":
      try .tag(container.decode(Tag.self, forKey: .payload))
    case let kind:
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unrecognized trait kind '\(kind)'"))
    }
  }

}
