//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A box type that encloses a value and makes it appear `Sendable` even when it
/// isn't.
///
/// This type should be used sparingly, and any use of it implies that the Swift
/// language is missing functionality or has a bug that the testing library
/// needs to work around.
///
/// This type is not part of the public interface of the testing library.
struct UncheckedSendable<T>: RawRepresentable, @unchecked Sendable {
  var rawValue: T

  init(rawValue: T) {
    self.rawValue = rawValue
  }
}

// MARK: - CustomStringConvertible, CustomDebugStringConvertible

extension UncheckedSendable: CustomStringConvertible where T: CustomStringConvertible {
  var description: String {
    rawValue.description
  }
}

extension UncheckedSendable: CustomDebugStringConvertible where T: CustomDebugStringConvertible {
  var debugDescription: String {
    rawValue.debugDescription
  }
}
