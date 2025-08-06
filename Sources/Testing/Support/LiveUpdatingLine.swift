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
/// This is ideal for creating single-line, live-updating progress bars or status indicators.
///
/// - Parameter text: The text to display on the current line
///
/// ## Technical Details
/// - Uses carriage return (`\r`) to move cursor to beginning of current line
/// - Uses ANSI escape code (`\u{001B}[2K`) to clear the entire line
/// - Does not append a newline character, allowing the line to be overwritten again
///
/// ## Example Usage
/// ```swift
/// printLiveUpdatingLine("Processing... 25%")
/// // Later...
/// printLiveUpdatingLine("Processing... 50%")
/// // Later...
/// printLiveUpdatingLine("Processing... 100%")
/// ```
public func printLiveUpdatingLine(_ text: String) {
  print("\r\u{001B}[2K\(text)", terminator: "")
} 
