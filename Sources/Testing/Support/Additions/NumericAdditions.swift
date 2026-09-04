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

  /// Conjugate an English verb whose subject is this number.
  ///
  /// - Parameters:
  ///   - singularVerb: The singular third-person form of the verb, e.g.
  ///     `"eats"` or `"is"`.
  ///   - pluralVerb: The plural third-person form of the verb, e.g. `"eat"` or
  ///     `"are"`.
  ///
  /// - Returns: Either `singularVerb` or `pluralVerb` depending on the value of
  ///   `self`.
  func counting(_ singularVerb: String, or pluralVerb: String) -> String {
    self == 1 ? singularVerb : pluralVerb
  }
}

// MARK: -

extension UInt8 {
  /// Whether or not this instance is an ASCII newline character (`\n` or `\r`).
  var isASCIINewline: Bool {
    self == UInt8(ascii: "\r") || self == UInt8(ascii: "\n")
  }
}
