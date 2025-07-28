//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type describing an ABI version number.
///
/// - Warning: This type is used to implement the testing library's ABI. Do not
///   use it directly.
public struct __ABIVersionNumber: Sendable {
  /// The major version.
  var majorComponent: Int = 0

  /// The minor version.
  var minorComponent: Int = 0

  /// The patch, revision, or bug fix version.
  var patchComponent: Int = 0
}

extension ABI {
  /// A type describing an ABI version number.
  typealias VersionNumber = __ABIVersionNumber
}

// MARK: - ExpressibleByIntegerLiteral, CustomStringConvertible

extension __ABIVersionNumber: ExpressibleByIntegerLiteral, CustomStringConvertible {
  public init(integerLiteral value: Int) {
    self.init(majorComponent: value)
  }

  /// Initialize an instance of this type by parsing the given string.
  ///
  /// - Parameters:
  ///   - string: The string to parse, such as `"0"` or `"6.3.0"`.
  ///
  /// @Comment {
  ///   - Bug: We are not able to reuse the logic from swift-syntax's
  ///     `VersionTupleSyntax` type here because we cannot link to swift-syntax
  ///     in this target.
  /// }
  public init?(_ string: String) {
    // Split the string on "." (assuming it is of the form "1", "1.2", or
    // "1.2.3") and parse the individual components as integers.
    let result: Self? = withUnsafeTemporaryAllocation(of: Int.self, capacity: 3) { componentNumbers in
      componentNumbers.initialize(repeating: 0)

      let components = string.split(separator: ".", maxSplits: 2, omittingEmptySubsequences: false)
      for (i, component) in zip(componentNumbers.indices, components) {
        guard let componentNumber = Int(component) else {
          // Couldn't parse this component as an integer, so bail.
          return nil
        }
        componentNumbers[i] = componentNumber
      }

      return Self(majorComponent: componentNumbers[0], minorComponent: componentNumbers[1], patchComponent: componentNumbers[2])
    }

    if let result {
      self = result
    } else {
      return nil
    }
  }

  public var description: String {
    if majorComponent <= 0 && minorComponent == 0 && patchComponent == 0 {
      return String(describing: majorComponent)
    } else if patchComponent == 0 {
      return "\(majorComponent).\(minorComponent)"
    }
    return "\(majorComponent).\(minorComponent).\(patchComponent)"
  }
}

// MARK: - Equatable, Comparable

extension __ABIVersionNumber: Equatable, Comparable {
  public static func <(lhs: Self, rhs: Self) -> Bool {
    if lhs.majorComponent != rhs.majorComponent {
      return lhs.majorComponent < rhs.majorComponent
    } else if lhs.minorComponent != rhs.minorComponent {
      return lhs.minorComponent < rhs.minorComponent
    } else if lhs.patchComponent != rhs.patchComponent {
      return lhs.patchComponent < rhs.patchComponent
    }
    return false
  }
}

// MARK: - Codable

extension __ABIVersionNumber: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let number = try? container.decode(Int.self) {
      self.init(majorComponent: number)
    } else {
      let string = try container.decode(String.self)
      guard let result = Self(string) else {
        throw DecodingError.dataCorrupted(
          .init(
            codingPath: decoder.codingPath,
            debugDescription: "Unexpected string '\(string)' (expected an integer or a string of the form '1.2.3')"
          )
        )
      }
      self = result
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    if majorComponent <= 0 && minorComponent == 0 && patchComponent == 0 {
      try container.encode(majorComponent)
    } else {
      try container.encode("\(majorComponent).\(minorComponent).\(patchComponent)")
    }
  }
}
