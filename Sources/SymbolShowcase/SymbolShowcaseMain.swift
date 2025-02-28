//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
import Foundation

/// A type which acts as the main entry point for this executable target.
@main enum SymbolShowcaseMain {
  static func main() {
    let nameColumnWidth = symbols.reduce(into: 0) { $0 = max($0, $1.0.count) } + 4
    let styleColumnWidth = styles.reduce(into: 0) { $0 = max($0, $1.label.count) } + 2
    let totalHeaderWidth = nameColumnWidth + (styleColumnWidth * styles.count)

    // Print the table header.
    print("Name".padding(toLength: nameColumnWidth), terminator: "")
    for style in styles {
      print(style.label.padding(toLength: styleColumnWidth), terminator: "")
    }
    print()
    print(String(repeating: "=", count: totalHeaderWidth))

    // Print a row for each symbol, with a preview of each style.
    for (label, symbol) in symbols {
      print(label.padding(toLength: nameColumnWidth), terminator: "")
      for style in styles {
        print(style.string(for: symbol), terminator: "")
        print("".padding(toLength: styleColumnWidth - 1), terminator: "")
      }
      print()
    }
  }

  /// The symbols to preview.
  fileprivate static var symbols: KeyValuePairs<String, Event.Symbol> {
    [
      "Default": .default,
      "Pass": .pass(knownIssueCount: 0),
      "Pass w/known issues": .pass(knownIssueCount: 1),
      "Pass with warnings": .passWithWarnings,
      "Skip": .skip,
      "Fail": .fail,
      "Difference": .difference,
      "Warning": .warning,
      "Details": .details,
      "Attachment": .attachment,
    ]
  }

  /// The styles to preview.
  fileprivate static var styles: [Style] {
    [
      Style(label: "Unicode", usesColor: false, usesSFSymbols: false),
      Style(label: "w/color", usesColor: true, usesSFSymbols: false),
      Style(label: "SF Symbols", usesColor: false, usesSFSymbols: true),
      Style(label: "w/color", usesColor: true, usesSFSymbols: true),
    ]
  }
}

/// A type representing a style of symbol to preview.
fileprivate struct Style {
  /// The label for this style, displayed in its column header.
  var label: String

  /// Whether this style should render symbols using ANSI color.
  var usesColor: Bool

  /// Whether this style should use SF Symbols.
  var usesSFSymbols: Bool

  /// Return a string for the specified symbol based on this style's options.
  ///
  /// - Parameters:
  ///   - symbol: The symbol to format into a string.
  ///
  /// - Returns: A formatted string representing the specified symbol.
  func string(for symbol: Event.Symbol) -> String {
    let options = Event.ConsoleOutputRecorder.Options(
      useANSIEscapeCodes: usesColor,
      ansiColorBitDepth: usesColor ? 8 : 1,
      useSFSymbols: usesSFSymbols
    )
    return symbol.stringValue(options: options)
  }
}

extension String {
  /// Returns a new string formed from this String by either removing characters
  /// from the end, or by appending as many occurrences as necessary of a given
  /// pad string.
  ///
  /// - Parameters:
  ///   - newLength: The length to pad to.
  ///
  /// - Returns: A padded string.
  fileprivate func padding(toLength newLength: Int) -> Self {
    padding(toLength: newLength, withPad: " ", startingAt: 0)
  }
}
