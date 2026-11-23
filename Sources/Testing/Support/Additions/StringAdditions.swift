//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension String {
#if hasFeature(Embedded)
  // WORKAROUND: https://github.com/swiftlang/swift/issues/88756
  func contains(_ other: some StringProtocol) -> Bool {
    self.indices.contains { self[$0...].hasPrefix(other) }
  }
#endif

  /// Make a copy of this string with all ASCII letters lowercased.
  ///
  /// - Returns: A lowercased copy of this string. Non-ASCII letters are not
  ///   modified.
  package func lowercasedASCII() -> String {
    let utf8 = self.utf8.lazy.map { c in
      if c >= UInt8(ascii: "A") && c <= UInt8(ascii: "Z") {
        return (c - UInt8(ascii: "A")) + UInt8(ascii: "a")
      }
      return c
    }
    return String(decoding: utf8, as: UTF8.self)
  }

  /// Make a copy of this string with all ASCII letters uppercased.
  ///
  /// - Returns: An uppercased copy of this string. Non-ASCII letters are not
  ///   modified.
  package func uppercasedASCII() -> String {
    let utf8 = self.utf8.lazy.map { c in
      if c >= UInt8(ascii: "a") && c <= UInt8(ascii: "z") {
        return (c - UInt8(ascii: "a")) + UInt8(ascii: "A")
      }
      return c
    }
    return String(decoding: utf8, as: UTF8.self)
  }
}
