//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// Prints a string to the console by overwriting the current line without creating a new line.
///
/// - Parameter text: The text to display on the current line
public func printLiveUpdatingLine(_ text: String) {
  print("\r\u{001B}[2K\(text)", terminator: "")
} 
