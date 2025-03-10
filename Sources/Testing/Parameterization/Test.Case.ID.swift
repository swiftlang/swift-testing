//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Test.Case {
  /// The ID of a test case.
  ///
  /// Instances of this type are considered unique within the scope of a given
  /// parameterized test function. They are not necessarily unique across two
  /// different ``Test`` instances.
  @_spi(ForToolsIntegrationOnly)
  public struct ID: Sendable {
    /// The IDs of the arguments of this instance's associated ``Test/Case``, in
    /// the order they appear in ``Test/Case/arguments``.
    ///
    /// The value of this property is `nil` for the ID of the single test case
    /// associated with a non-parameterized test function.
    public var argumentIDs: [Argument.ID]?

    /// A number used to distinguish this test case from others associated with
    /// the same parameterized test function whose arguments have the same ID.
    ///
    /// The value of this property is `nil` for the ID of the single test case
    /// associated with a non-parameterized test function.
    ///
    /// ## See Also
    ///
    /// - ``Test/Case/discriminator``
    public var discriminator: Int?

    init(argumentIDs: [Argument.ID]?, discriminator: Int?) {
      precondition((argumentIDs == nil) == (discriminator == nil))

      self.argumentIDs = argumentIDs
      self.discriminator = discriminator
    }

    /// Whether or not this test case ID is considered stable across successive
    /// runs.
    ///
    /// The value of this property is `true` if all of the argument IDs for this
    /// instance are stable, otherwise it is `false`.
    public var isStable: Bool {
      (argumentIDs ?? []).allSatisfy(\.isStable)
    }
  }

  @_spi(ForToolsIntegrationOnly)
  public var id: ID {
    ID(argumentIDs: arguments.map { $0.map(\.id) }, discriminator: discriminator)
  }
}

// MARK: - CustomStringConvertible

extension Test.Case.ID: CustomStringConvertible {
  public var description: String {
    if let argumentIDs, let discriminator {
      "argumentIDs: \(argumentIDs), discriminator: \(discriminator)"
    } else {
      "non-parameterized"
    }
  }
}

// MARK: - Codable

extension Test.Case.ID: Codable {
  public init(from decoder: some Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // The `argumentIDs` property is Optional but the meaning of `nil` has
    // changed since this type was first introduced: it now identifies a
    // non-parameterized test case, whereas it originally identified a
    // parameterized test case for which one or more arguments could not be
    // encoded. If it's present in the decoding container, accept whatever value
    // is decoded (which may be `nil`). If it's absent, default to a single
    // argument ID marked as non-stable to maintain previous behavior.
    let argumentIDs: [Test.Case.Argument.ID]? = if container.contains(.argumentIDs) {
      try container.decode(type(of: argumentIDs), forKey: .argumentIDs)
    } else {
      [Test.Case.Argument.ID(bytes: [], isStable: false)]
    }

    // The `discriminator` property was added after this type was first
    // introduced. If it's present in the decoding container, accept whatever
    // value is decoded (which may be `nil`). If it's absent, default to `nil`
    // if `argumentIDs` was interpreted as a non-parameterized test above, or
    // else 0, to maintain previous behavior.
    let discriminator: Int? = if container.contains(.discriminator) {
      try container.decode(type(of: discriminator), forKey: .discriminator)
    } else {
      if let argumentIDs {
        argumentIDs.isEmpty ? nil : 0
      } else {
        nil
      }
    }

    self.init(argumentIDs: argumentIDs, discriminator: discriminator)
  }

  public func encode(to encoder: some Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    // The `argumentIDs` property is Optional but the meaning of `nil` has
    // changed since this type was first introduced: it now identifies a
    // non-parameterized test case, whereas it originally identified a
    // parameterized test case for which one or more arguments could not be
    // encoded. Explicitly encode `nil` values here, rather than omitting them,
    // so that when decoding we can distinguish these two scenarios.
    try container.encode(argumentIDs, forKey: .argumentIDs)

    // The `discriminator` property was added after this type was first
    // introduced. Explicitly encode `nil` values here, rather than omitting
    // them, so that when decoding we can distinguish the older vs. newer
    // implementations.
    try container.encode(discriminator, forKey: .discriminator)
  }
}

// MARK: - Equatable, Hashable

extension Test.Case.ID: Hashable {}
