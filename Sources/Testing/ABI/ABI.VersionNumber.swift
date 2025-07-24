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
  var major: Int = 0

  /// The minor version.
  var minor: Int = 0

  /// The patch, revision, or bug fix version.
  var patch: Int = 0
}

extension ABI {
  /// A type describing an ABI version number.
  typealias VersionNumber = __ABIVersionNumber
}

// MARK: - ExpressibleByIntegerLiteral, CustomStringConvertible

extension __ABIVersionNumber: ExpressibleByIntegerLiteral, CustomStringConvertible {
  public init(integerLiteral value: Int) {
    self.init(major: value)
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

      return Self(major: componentNumbers[0], minor: componentNumbers[1], patch: componentNumbers[2])
    }

    if let result {
      self = result
    } else {
      return nil
    }
  }

  public var description: String {
    if major <= 0 && minor == 0 && patch == 0 {
      return String(describing: major)
    } else if patch == 0 {
      return "\(major).\(minor)"
    }
    return "\(major).\(minor).\(patch)"
  }
}

// MARK: - Equatable, Comparable

extension __ABIVersionNumber: Equatable, Comparable {
  public static func <(lhs: Self, rhs: Self) -> Bool {
    if lhs.major != rhs.major {
      return lhs.major < rhs.major
    } else if lhs.minor != rhs.minor {
      return lhs.minor < rhs.minor
    } else if lhs.patch != rhs.patch {
      return lhs.patch < rhs.patch
    }
    return false
  }
}

// MARK: - Codable

extension __ABIVersionNumber: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let number = try? container.decode(Int.self) {
      self.init(major: number)
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
    if major <= 0 && minor == 0 && patch == 0 {
      try container.encode(major)
    } else {
      try container.encode("\(major).\(minor).\(patch)")
    }
  }
}
