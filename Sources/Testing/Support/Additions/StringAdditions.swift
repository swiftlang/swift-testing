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
}

// MARK: -

extension StaticString {
  /// This string as a compile-time constant C string.
  ///
  /// - Precondition: This instance of `StaticString` must have been constructed
  ///   from a string literal, not a Unicode scalar value.
  var constUTF8CString: UnsafePointer<CChar> {
    precondition(hasPointerRepresentation, "Cannot construct a compile-time constant C string from a StaticString without pointer representation.")
    return UnsafeRawPointer(utf8Start).bindMemory(to: CChar.self, capacity: utf8CodeUnitCount)
  }
}
