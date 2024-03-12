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
  @_spi(ForToolsIntegrationOnly)
  public struct ConsoleOutputRecorder: Sendable, ~Copyable {
    /// An enumeration describing options to use when writing events to a
    /// stream.
    public enum Option: Sendable {
      /// Use [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
      /// to add color and other effects to the output.
      ///
      /// - Parameters:
      ///   - colorBitDepth: The supported color bit depth. Allowed values are
      ///     `1` (escape code support, but no color support), `4` (16-color),
      ///     `8` (256-color), and `24` (true color.)
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
      ///
      /// If this option is used more than once, the instance with the highest
      /// supported value for `colorBitDepth` is used.
      case useANSIEscapeCodes(colorBitDepth: Int8)

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
      /// This option is ignored unless ``useANSIEscapeCodes(colorBitDepth:)``
      /// is also specified.
      case useTagColors(_ tagColors: [Tag: Tag.Color])

      /// Record verbose output.
      ///
      /// When specified, additional output is provided. The exact nature of the
      /// additional output is implementation-defined and subject to change.
      case useVerboseOutput
    }

    /// The options for this event recorder.
    var options: Set<Option>

    /// The tag colors this event recorder should use.
    ///
    /// The initial value of this property is derived from `options`.
    var tagColors: [Tag: Tag.Color]

    /// The write function for this event recorder.
    var write: @Sendable (String) -> Void

    /// The underlying human-readable recorder.
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
      self.tagColors = options.reduce(into: Tag.Color.predefined) { tagColors, option in
        if case let .useTagColors(someTagColors) = option {
          tagColors.merge(
            someTagColors.filter { !$0.key.isPredefinedColor },
            uniquingKeysWith: { _, rhs in rhs }
          )
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
    var useColorANSIEscapeCodes = false
    if let colorBitDepth = options.colorBitDepth {
      useColorANSIEscapeCodes = colorBitDepth >= 4
    }

    var symbolCharacter = String(unicodeCharacter)
#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
    if options.contains(.useSFSymbols) {
      symbolCharacter = "\(sfSymbolCharacter) "
    }
#endif

    if useColorANSIEscapeCodes {
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
  ///   ``Event/Recorder/Option/useANSIEscapeCodes(colorBitDepth:)`` option is
  ///   not specified, returns `nil`.
  fileprivate func ansiEscapeCode(options: Set<Event.ConsoleOutputRecorder.Option>) -> String? {
    guard let colorBitDepth = options.colorBitDepth, colorBitDepth >= 4 else {
      return nil
    }
    if colorBitDepth >= 24 {
      return "\(_ansiEscapeCodePrefix)38;2;\(redComponent);\(greenComponent);\(blueComponent)m"
    }
    if colorBitDepth >= 8 {
      // The formula for converting an RGB value to a 256-color ANSI color
      // code can be found at https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
      let r = (Int(redComponent) * 5) / Int(UInt8.max)
      let g = (Int(greenComponent) * 5) / Int(UInt8.max)
      let b = (Int(blueComponent) * 5) / Int(UInt8.max)
      let index = 16 + 36 * r + 6 * g + b
      return "\(_ansiEscapeCodePrefix)38;5;\(index)m"
    }
    return closest16ColorEscapeCode()
  }

  /// Get the ANSI escape code that sets the foreground text color to whichever
  /// 16-color value is closest to this instance.
  ///
  /// - Returns: The corresponding ANSI escape code.
  ///
  /// An idealized color space is assumed.
  func closest16ColorEscapeCode() -> String {
    if self == .orange {
      // Special-case orange to dark yellow as it doesn't have a good mapping in
      // most low-color terminals. NOTE: Historically, the IBM PC's CGA adapter
      // and monitor had dedicated circuitry to display dark yellow as a shade
      // of orange-brown, but modern terminal applications rarely emulate it.
      return "\(_ansiEscapeCodePrefix)33m"
    } else if self == .purple {
      // Special-case purple as well since it is declared as true purple rather
      // than magenta.
      return "\(_ansiEscapeCodePrefix)95m"
    }

    let (hue, saturation, value) = hsvComponents
    if saturation <= 0.25 {
      // Some shade of gray (or a very pale color.)
      let colorValue = switch Int(value * 3.0) {
      case 0: // black
        30
      case 1: // dark gray
        90
      case 2: // light gray
        37
      default: // 3, white
        97
      }
      return "\(_ansiEscapeCodePrefix)\(colorValue)m"
    } else {
      // There is some saturation, so figure out the closest available color.
      let brightAddend = if value > 0.5 {
        60
      } else {
        0
      }
      let hueAddend = switch Int(hue * 6.0) {
      case 0, 6: // red
        31
      case 1: // yellow
        33
      case 2: // green
        32
      case 3: // cyan
        36
      case 4: // blue
        34
      default: // 5, magenta
        35
      }
      return "\(_ansiEscapeCodePrefix)\(hueAddend + brightAddend)m"
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
    let tagColors = tagColors
    let unsortedColors = tags.lazy.compactMap { tagColors[$0] }

    let options = options
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

extension Collection where Element == Event.ConsoleOutputRecorder.Option {
  /// The color bit depth associated with the options in this collection, if
  /// any.
  ///
  /// If this collection contains any instances of case
  /// ``useANSIEscapeCodes(colorBitDepth:)``, the value of this property is
  /// their highest associated value. Otherwise, the value of this property is
  /// `nil`.
  var colorBitDepth: Int8? {
    lazy.compactMap { option in
      if case let .useANSIEscapeCodes(colorBitDepth) = option {
        return colorBitDepth
      }
      return nil
    }.max()
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
    let verbose = options.contains(.useVerboseOutput)
    let messages = _humanReadableOutputRecorder.record(event, in: context, verbosely: verbose)
    for message in messages {
      let symbol = message.symbol?.stringValue(options: options) ?? " "

      if case .details = message.symbol, options.colorBitDepth != nil {
        // Special-case the detail symbol to apply grey to the entire line of
        // text instead of just the symbol.
        write("\(_ansiEscapeCodePrefix)90m\(symbol) \(message.stringValue)\(_resetANSIEscapeCode)\n")
      } else {
        let colorDots = context.test.map(\.tags).map { self.colorDots(for: $0) } ?? ""
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
    return "\(symbol) \(message)\n"
  }
}
