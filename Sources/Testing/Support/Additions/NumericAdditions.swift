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
