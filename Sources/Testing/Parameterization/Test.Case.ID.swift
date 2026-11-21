//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Synchronization)
private import Synchronization
#endif

extension Test.Case: Identifiable {
  /// The ID of a test case.
  ///
  /// Instances of this type are considered unique within the scope of a given
  /// parameterized test function. They are not necessarily unique across two
  /// different ``Test`` instances.
  public struct ID: Sendable {
    /// Storage for ``argumentIDs``.
    private var _argumentIDs: [Argument.ID]?

    /// The IDs of the arguments of this instance's associated ``Test/Case``.
    ///
    /// For a parameterized test case, this array contains a single element: an
    /// ``Test/Case/Argument/ID-swift.struct`` that combines the IDs of every
    /// argument. The value of this property is `nil` for the ID of the single
    /// test case associated with a non-parameterized test function.
    @_spi(ForToolsIntegrationOnly)
    public var argumentIDs: [Argument.ID]? {
      get {
        _argumentIDs.map { [Argument.ID(combining: $0)] }
      }
      set {
        _argumentIDs = newValue
      }
    }

    /// A number used to distinguish this test case from others associated with
    /// the same parameterized test function whose arguments have the same ID.
    ///
    /// The value of this property is `nil` for the ID of the single test case
    /// associated with a non-parameterized test function.
    ///
    /// ## See Also
    ///
    /// - ``Test/Case/discriminator``
    @_spi(ForToolsIntegrationOnly)
    public var discriminator: Int?

    /// Whether or not this test case ID is considered stable across successive
    /// runs.
    @_spi(ForToolsIntegrationOnly)
    public var isStable: Bool

    init(argumentIDs: [Argument.ID]?, discriminator: Int?, isStable: Bool) {
      precondition((argumentIDs == nil) == (discriminator == nil))

      self._argumentIDs = argumentIDs
      self.discriminator = discriminator
      self.isStable = isStable
    }
  }

  @_spi(ForToolsIntegrationOnly)
  public var id: ID {
    ID(argumentIDs: arguments?.map { $0.id }, discriminator: discriminator, isStable: isStable)
  }
}

// MARK: - CustomStringConvertible, CustomTestStringConvertible

extension Test.Case.ID: CustomStringConvertible {
  public var description: String {
    // The description of a test case ID is opaque. We currently implement it as
    // a SHA-256 hash of its properties, but this is subject to change.
    let argumentIDs = argumentIDs ?? []
    var bytes: [UInt8] = Array(argumentIDs.lazy.map(\.bytes).joined())
    if let discriminator {
      withUnsafeBytes(of: discriminator.littleEndian) { bytes += $0 }
    }
    bytes.append(isStable ? 1 : 0)
    let hash = SHA256.hash(bytes)
    return hash.map { byte in
      byte >= 0x10 ? String(byte, radix: 16) : "0\(String(byte, radix: 16))"
    }.joined()
  }
}

#if DEBUG
extension Test.Case.ID: CustomTestStringConvertible {
  public var testDescription: String {
    // Pass through Comment to make sure string interpolation uses
    // CustomTestStringConvertible instead of just CustomStringConvertible in
    // Embedded Swift.
    let result: Comment = if let argumentIDs, let discriminator {
      "Parameterized test case ID: argumentIDs: \(argumentIDs), discriminator: \(discriminator), isStable: \(isStable)"
    } else {
      "Non-parameterized test case ID"
    }
    return result.rawValue
  }
}
#endif

#if !SWT_NO_SNAPSHOT_TYPES
// MARK: - Codable

extension Test.Case.ID {
  /// A snapshot equivalent of a test case ID.
  struct Snapshot: Sendable, RawRepresentable {
    var rawValue: Test.Case.ID
  }
}

extension Test.Case.ID.Snapshot: Codable {
  private enum _CodingKeys: String, CodingKey {
    /// A coding key for ``Test/Case/ID/argumentIDs``.
    ///
    /// This case's string value is non-standard because a previous legacy
    /// argument ID key used it, and clients have adjusted to this one.
    case argumentIDs = "argIDs"

    /// A coding key for ``Test/Case/ID/discriminator``.
    case discriminator

    /// A coding key for ``Test/Case/ID/isStable``.
    case isStable
  }

  func encode(to encoder: any Encoder) throws(any Error) {
    var container = encoder.container(keyedBy: _CodingKeys.self)
    try container.encodeIfPresent(rawValue._argumentIDs, forKey: .argumentIDs)
    try container.encodeIfPresent(rawValue.discriminator, forKey: .discriminator)
    try container.encode(rawValue.isStable, forKey: .isStable)
  }

  init(from decoder: any Decoder) throws(any Error) {
    let container = try decoder.container(keyedBy: _CodingKeys.self)
    rawValue = try Test.Case.ID(
      argumentIDs: container.decodeIfPresent([Test.Case.Argument.ID].self, forKey: .argumentIDs),
      discriminator: container.decodeIfPresent(Int.self, forKey: .discriminator),
      isStable: container.decode(Bool.self, forKey: .isStable)
    )
  }
}
#endif

// MARK: - Equatable, Hashable

extension Test.Case.ID: Equatable, Hashable {}
