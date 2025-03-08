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
    public var argumentIDs: [Argument.ID]

    /// A number used to distinguish this test case from others associated with
    /// the same test function whose arguments have the same ID.
    ///
    /// ## See Also
    ///
    /// - ``Test/Case/discriminator``
    public var discriminator: Int

    public init(argumentIDs: [Argument.ID], discriminator: Int) {
      self.argumentIDs = argumentIDs
      self.discriminator = discriminator
    }

    /// Whether or not this test case ID is considered stable across successive
    /// runs.
    ///
    /// The value of this property is `true` if all of the argument IDs for this
    /// instance are stable, otherwise it is `false`.
    public var isStable: Bool {
      argumentIDs.allSatisfy(\.isStable)
    }
  }

  @_spi(ForToolsIntegrationOnly)
  public var id: ID {
    ID(argumentIDs: arguments.map(\.id), discriminator: discriminator)
  }
}

// MARK: - CustomStringConvertible

extension Test.Case.ID: CustomStringConvertible {
  public var description: String {
    "argumentIDs: \(argumentIDs), discriminator: \(discriminator)"
  }
}

// MARK: - Codable

extension Test.Case.ID: Codable {
  public init(from decoder: some Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // The `argumentIDs` property was optional when this type was first
    // introduced, and a `nil` value represented a non-stable test case ID.
    // To maintain previous behavior, if this value is absent when decoding,
    // default to a single argument ID marked as non-stable.
    let argumentIDs = try container.decodeIfPresent([Test.Case.Argument.ID].self, forKey: .argumentIDs)
      ?? [Test.Case.Argument.ID(bytes: [], isStable: false)]

    // The `discriminator` property was added after this type was first
    // introduced. It can safely default to zero when absent.
    let discriminator = try container.decodeIfPresent(type(of: discriminator), forKey: .discriminator) ?? 0

    self.init(argumentIDs: argumentIDs, discriminator: discriminator)
  }
}

// MARK: - Equatable, Hashable

extension Test.Case.ID: Hashable {}
