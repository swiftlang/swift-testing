//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension CommandLine {
  /// Get the command-line arguments passed to this process.
  ///
  /// - Returns: An array of command-line arguments.
  ///
  /// This function works around a bug in the Swift standard library that causes
  /// the built-in `CommandLine.arguments` property to not be concurrency-safe.
  /// ([swift-#66213](https://github.com/apple/swift/issues/66213))
  static func arguments() -> [String] {
    UnsafeBufferPointer(start: unsafeArgv, count: Int(argc)).lazy
      .compactMap { $0 }
      .compactMap { String(validatingUTF8: $0) }
  }
}
