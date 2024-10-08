//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Numeric {
  /// Form an English noun phrase describing this number of values.
  ///
  /// - Parameters:
  ///   - noun: A singular noun describing the kind of values being counted,
  ///     such as `"issue"` or `"test"`.
  ///
  /// - Returns: An English-language string composed of `self` and `noun`, with
  ///   `noun` being pluralized if `self` does not equal `1`. For example,
  ///   `5.counting("duck")` produces `"5 ducks"`.
  func counting(_ noun: String) -> String {
    if self == 1 {
      return "1 \(noun)"
    }
    return "\(self) \(noun)s"
  }
}

// MARK: -

extension UInt8 {
  /// Whether or not this instance is an ASCII newline character (`\n` or `\r`).
  var isASCIINewline: Bool {
    self == UInt8(ascii: "\r") || self == UInt8(ascii: "\n")
  }
}

// MARK: -

extension Int {
  /// Get the next integer after this one that is properly aligned to store a
  /// value of type `T`.
  ///
  /// - Parameters:
  ///   - type: the type whose alignment should be used to compute the result.
  ///
  /// - Returns: an integer greater than or equal to `self` whose value is
  ///   properly aligned to store a value of type `T`.
  func alignedUp(for type: (some Any).Type) -> Self {
    Self(bitPattern: UnsafeRawPointer(bitPattern: self)?.alignedUp(for: type))
  }
}
