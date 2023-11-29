//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Event {
  /// A type which handles ``Event`` instances and outputs representations of
  /// them as human-readable strings.
  ///
  /// The format of the output is not meant to be machine-readable and is
  /// subject to change. For machine-readable output, use ``JUnitXMLRecorder``.
  public struct ConsoleOutputRecorder: Sendable {
    /// An enumeration describing options to use when writing events to a
    /// stream.
    public enum Option: Sendable {
      /// Use [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
      /// to add color and other effects to the output.
      ///
      /// This option is useful when writing command-line output (for example,
      /// in Terminal.app on macOS.)
      ///
      /// As a general rule, standard output can be assumed to support ANSI
      /// escape codes on POSIX-like operating systems when the `"TERM"`
      /// environment variable is set _and_ `isatty(STDOUT_FILENO)` returns
      /// non-zero.
      ///
      /// On Windows, `GetFileType()` returns `FILE_TYPE_CHAR` for console file
      /// handles, and the [Console API](https://learn.microsoft.com/en-us/windows/console/)
      /// can be used to perform more complex console operations.
      case useANSIEscapeCodes

      /// Whether or not to use 256-color extended
      /// [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code) to
      /// add color to the output.
      ///
      /// This option is ignored unless ``useANSIEscapeCodes`` is also
      /// specified.
      case use256ColorANSIEscapeCodes

#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
      /// Use [SF&nbsp;Symbols](https://developer.apple.com/sf-symbols/) in the
      /// output.
      ///
      /// When this option is used, SF&nbsp;Symbols are assumed to be present in
      /// the font used for rendering within the Unicode Private Use Area. If
      /// the SF&nbsp;Symbols app is not installed on the system where the
      /// output is being rendered, the effect of this option is unspecified.
      case useSFSymbols
#endif

      /// Use the specified mapping of tags to color.
      ///
      /// - Parameters:
      ///   - tagColors: A dictionary whose keys are tags and whose values are
      ///     the colors to use for those tags.
      ///
      /// When this option is used, tags on tests that have assigned colors in
      /// the associated `tagColors` dictionary are presented as colored dots
      /// prior to the tests' names.
      ///
      /// If this option is specified more than once, the associated `tagColors`
      /// dictionaries of each option are merged. If the keys of those
      /// dictionaries overlap, the result is unspecified.
      ///
      /// The tags ``Tag/red``, ``Tag/orange``, ``Tag/yellow``, ``Tag/green``,
      /// ``Tag/blue``, and ``Tag/purple`` always have assigned colors even if
      /// this option is not specified, and those colors cannot be overridden by
      /// this option.
      ///
      /// This option is ignored unless ``useANSIEscapeCodes`` is also
      /// specified.
      case useTagColors(_ tagColors: [Tag: Tag.Color])
    }

    /// The options for this event recorder.
    var options: Set<Option>

    /// The set of predefined tag colors that are always set even when
    /// ``Option/useTagColors(_:)`` is not specified.
    private static let _predefinedTagColors: [Tag: Tag.Color] = [
      .red: .red, .orange: .orange, .yellow: .yellow,
      .green: .green, .blue: .blue, .purple: .purple,
    ]

    /// The tag colors this event recorder should use.
    ///
    /// The initial value of this property is derived from `options`.
    var tagColors: [Tag: Tag.Color]

    /// The write function for this event recorder.
    var write: @Sendable (String) -> Void

    private var _humanReadableOutputRecorder = HumanReadableOutputRecorder()

    /// Initialize a new event recorder.
    ///
    /// - Parameters:
    ///   - options: The options this event recorder should use when calling
    ///     `write`. Defaults to the empty array.
    ///   - write: A closure that writes output to its destination. The closure
    ///     may be invoked concurrently.
    ///
    /// Output from the testing library is written using `write`. The format of
    /// the output is not meant to be machine-readable and is subject to change.
    public init(options: [Option] = [], writingUsing write: @escaping @Sendable (String) -> Void) {
      self.options = Set(options)
      self.tagColors = options.reduce(into: Self._predefinedTagColors) { tagColors, option in
        if case let .useTagColors(someTagColors) = option {
          tagColors.merge(someTagColors, uniquingKeysWith: { lhs, _ in lhs })
        }
      }
      self.write = write
    }
  }
}

// MARK: - Equatable, Hashable

extension Event.ConsoleOutputRecorder.Option: Equatable, Hashable {}

// MARK: - ANSI Escape Code support

/// The ANSI escape code prefix.
private let _ansiEscapeCodePrefix = "\u{001B}["

/// The ANSI escape code to reset text output to default settings.
private let _resetANSIEscapeCode = "\(_ansiEscapeCodePrefix)0m"

extension Event.Symbol {
  /// Get the string value for this symbol with the given write options.
  ///
  /// - Parameters:
  ///   - options: Options to use when writing this symbol.
  ///
  /// - Returns: A string representation of `self` appropriate for writing to
  ///   a stream.
  fileprivate func stringValue(options: Set<Event.ConsoleOutputRecorder.Option>) -> String {
    var symbolCharacter = String(unicodeCharacter)
#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
    if options.contains(.useSFSymbols) {
      symbolCharacter = String(sfSymbolCharacter)
      if options.contains(.useANSIEscapeCodes) {
        symbolCharacter += " "
      }
    }
#endif

    if options.contains(.useANSIEscapeCodes) {
      switch self {
      case .default, .skip, .difference:
        return "\(_ansiEscapeCodePrefix)90m\(symbolCharacter)\(_resetANSIEscapeCode)"
      case let .pass(knownIssueCount):
        if knownIssueCount > 0 {
          return "\(_ansiEscapeCodePrefix)90m\(symbolCharacter)\(_resetANSIEscapeCode)"
        }
        return "\(_ansiEscapeCodePrefix)92m\(symbolCharacter)\(_resetANSIEscapeCode)"
      case .fail:
        return "\(_ansiEscapeCodePrefix)91m\(symbolCharacter)\(_resetANSIEscapeCode)"
      case .warning:
        return "\(_ansiEscapeCodePrefix)93m\(symbolCharacter)\(_resetANSIEscapeCode)"
      case .details:
        return symbolCharacter
      }
    }
    return "\(symbolCharacter)"
  }
}

extension Tag.Color {
  /// Get an ANSI escape code that sets the foreground text color to this color.
  ///
  /// - Parameters:
  ///   - options: Options to use when writing this tag.
  ///
  /// - Returns: The corresponding ANSI escape code. If the
  ///   ``Event/Recorder/Option/useANSIEscapeCodes`` option is not specified,
  ///   returns `nil`.
  fileprivate func ansiEscapeCode(options: Set<Event.ConsoleOutputRecorder.Option>) -> String? {
    guard options.contains(.useANSIEscapeCodes) else {
      return nil
    }
    if options.contains(.use256ColorANSIEscapeCodes) {
      // The formula for converting an RGB value to a 256-color ANSI color
      // code can be found at https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
      let r = (Int(redComponent) * 5) / Int(UInt8.max)
      let g = (Int(greenComponent) * 5) / Int(UInt8.max)
      let b = (Int(blueComponent) * 5) / Int(UInt8.max)
      let index = 16 + 36 * r + 6 * g + b
      return "\(_ansiEscapeCodePrefix)38;5;\(index)m"
    }
    switch self {
    case .red:
      return "\(_ansiEscapeCodePrefix)91m"
    case .orange:
      return "\(_ansiEscapeCodePrefix)33m"
    case .yellow:
      return "\(_ansiEscapeCodePrefix)93m"
    case .green:
      return "\(_ansiEscapeCodePrefix)92m"
    case .blue:
      return "\(_ansiEscapeCodePrefix)94m"
    case .purple:
      return "\(_ansiEscapeCodePrefix)95m"
    default:
      // TODO: HSL or HSV conversion followed by conversion to 16 colors.
      return nil
    }
  }
}

extension Event.ConsoleOutputRecorder {
  /// Generate a printable string describing the colors of a set of tags
  /// suitable for display in test output.
  ///
  /// - Parameters:
  ///   - tags: The tags for which colors are needed.
  ///
  /// - Returns: A string describing the colors of `tags` as bullet characters
  ///   with ANSI escape codes used to colorize them. If ANSI escape codes are
  ///   not enabled or if no tag colors are set, returns the empty string.
  fileprivate func colorDots(for tags: Set<Tag>) -> String {
    let unsortedColors = tags.lazy
      .compactMap { tag in
        if let tagColor = tagColors[tag] {
          return tagColor
        } else if let sourceCode = tag.sourceCode.map(String.init(describing:)) {
          // If the color is defined under a key such as ".foo" and the tag was
          // created from the expression `.foo`, we can find that too.
          return tagColors[Tag(rawValue: sourceCode)]
        }
        return nil
      }

    var result: String = Set(unsortedColors)
      .sorted(by: <).lazy
      .compactMap { $0.ansiEscapeCode(options: options) }
      .map { "\($0)\u{25CF}" } // Unicode: BLACK CIRCLE
      .joined()
    if !result.isEmpty {
      result += "\(_resetANSIEscapeCode) "
    }
    return result
  }
}

// MARK: -

extension Event.ConsoleOutputRecorder {
  /// Record the specified event by generating a representation of it in this
  /// instance's output format and writing it to this instance's destination.
  ///
  /// - Parameters:
  ///   - event: The event to record.
  ///   - context: The context associated with the event.
  ///
  /// - Returns: Whether any output was produced and written to this instance's
  ///   destination.
  @discardableResult public func record(_ event: borrowing Event, in context: borrowing Event.Context) -> Bool {
    let messages = _humanReadableOutputRecorder.record(event, in: context)
    for message in messages {
      let symbol = message.symbol?.stringValue(options: options) ?? " "

      if case .details = message.symbol, options.contains(.useANSIEscapeCodes) {
        // Special-case the detail symbol to apply grey to the entire line of
        // text instead of just the symbol.
        write("\(_ansiEscapeCodePrefix)90m\(symbol) \(message.stringValue)\(_resetANSIEscapeCode)\n")
      } else {
        let colorDots = context.test.map(\.tags).map(colorDots(for:)) ?? ""
        write("\(symbol) \(colorDots)\(message.stringValue)\n")
      }
    }
    return !messages.isEmpty
  }


  /// Get a message warning the user of some condition in the library that may
  /// affect test results.
  ///
  /// - Parameters:
  ///   - message: The message to present to the user.
  ///   - options: The options that should be used when formatting the resulting
  ///     message.
  ///
  /// - Returns: The described message, formatted for display using `options`.
  ///
  /// The caller is responsible for presenting this message to the user.
  static func warning(_ message: String, options: [Event.ConsoleOutputRecorder.Option]) -> String {
    let symbol = Event.Symbol.warning.stringValue(options: Set(options))
    return "\(symbol) \(message)"
  }
}
