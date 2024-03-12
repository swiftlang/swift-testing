//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ForToolsIntegrationOnly)
extension Test.Case: Identifiable {
  /// The ID of a test case.
  ///
  /// Instances of this type are considered unique within the scope of a given
  /// parameterized test function. They are not necessarily unique across two
  /// different ``Test`` instances.
  public struct ID: Sendable, Equatable, Hashable {
    /// The IDs of the arguments of this instance's associated ``Test/Case``, in
    /// the order they appear in ``Test/Case/arguments``.
    ///
    /// The value of this property is `nil` if _any_ of the associated test
    /// case's arguments has a `nil` ID.
    public var argumentIDs: [Argument.ID]?

    public init(argumentIDs: [Argument.ID]?) {
      self.argumentIDs = argumentIDs
    }
  }

  public var id: ID {
    let argumentIDs = arguments.compactMap(\.id)
    guard argumentIDs.count == arguments.count else {
      return ID(argumentIDs: nil)
    }

    return ID(argumentIDs: argumentIDs)
  }
}

// MARK: - CustomStringConvertible

extension Test.Case.ID: CustomStringConvertible {
  public var description: String {
    "argumentIDs: \(String(describing: argumentIDs))"
  }
}

// MARK: - Codable

extension Test.Case.ID: Codable {}

// MARK: - Equatable

// We cannot safely implement Equatable for Test.Case because its values are
// type-erased. It does conform to `Identifiable`, but its ID type is composed
// of the IDs of its arguments, and those IDs are not always available (for
// example, if the type of an argument is not Codable). Thus, we cannot check
// for equality of test cases based on this, because if two test cases had
// different arguments, but the type of those arguments is not Codable, they
// both will have a `nil` ID and would incorrectly be considered equal.
//
// `Test.Case.ID` is Equatable, however.
