//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ExperimentalParameterizedTesting)
extension Test.Case: Identifiable {
  /// The ID of a test case.
  ///
  /// Instances of this type are considered unique within the scope of a given
  /// parameterized test function. They are not necessarily unique across two
  /// different ``Test`` instances.
  public struct ID: Sendable, Equatable, Hashable {
    /// The IDs of the arguments of this instance's associated ``Test/Case``, in
    /// the order they appear in ``Test/Case/arguments``.
    public var argumentIDs: [String]

    @_spi(ExperimentalTestRunning)
    public init(argumentIDs: [String]) {
      self.argumentIDs = argumentIDs
    }
  }

  public var id: ID {
    ID(argumentIDs: arguments.map(\.id))
  }
}

// MARK: - CustomStringConvertible

extension Test.Case.ID: CustomStringConvertible {
  public var description: String {
    argumentIDs.joined(separator: "/")
  }
}

// MARK: - Codable

extension Test.Case.ID: Codable {}

// MARK: - Equatable, Hashable

extension Test.Case: Equatable, Hashable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
