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
  /// An enumeration describing the symbols used as prefixes when recording an
  /// event.
  @_spi(ForToolsIntegrationOnly)
  public enum Symbol: Sendable {
    /// The default symbol to use.
    case `default`

    /// The symbol to use when a test is skipped.
    case skip

    /// The symbol to use when a test passes.
    ///
    /// - Parameters:
    ///   - knownIssueCount: The number of known issues recorded for the test.
    ///     The default value is `0`.
    case pass(knownIssueCount: Int = 0)

    /// The symbol to use when a test passes with one or more warnings.
    @_spi(Experimental)
    @available(*, deprecated, renamed: "warning")
    static var passWithWarnings: Self { .warning }

    /// The symbol to use when a test fails.
    case fail

    /// The symbol to use when an expectation includes a difference description.
    case difference

    /// A warning or caution symbol to use when the developer should be aware of
    /// some condition, or if a test passes with one or more warnings.
    case warning

    /// The symbol to use when presenting details about an event to the user.
    case details

    /// The symbol to use when describing an instance of ``Attachment``.
    case attachment

    /// A custom symbol.
    ///
    /// - Parameters:
    ///   - unicodeCharacter: The Unicode character to use to represent this
    ///     symbol in text-based output.
    ///   - windowsCharacter: The Unicode character to use to represent this
    ///     symbol in text-based output on Windows, where the default console
    ///     font has more limited Unicode support.
    ///   - asciiCharacters: A sequence of ASCII characters to use to represent
    ///     this symbol in text-based output where Unicode is not supported. The
    ///     effect of including non-ASCII characters in this array is undefined.
    ///   - sfSymbolCharacter: The character corresponding to this symbol in the
    ///     SF&nbsp;Symbols system font.
    ///   - sfSymbolName: The name of the SF&nbsp;Symbol corresponding to this
    ///     symbol.
    ///   - color: The color to use when rendering this symbol, if any.
    case custom(
      unicodeCharacter: Character,
      windowsCharacter: Character,
      asciiCharacters: [UInt8],
      sfSymbolCharacter: Character,
      sfSymbolName: String,
      color: Color? = nil
    )
  }
}

#if os(anyAppleOS)
// MARK: - SF Symbols

extension Event.Symbol {
  /// The SF&nbsp;Symbols character and name corresponding to this instance.
  private var _sfSymbolInfo: (privateUseAreaCharacter: Character, name: String) {
    switch self {
    case .default:
      ("\u{1007C8}", "diamond")
    case .skip:
      ("\u{10065F}", "arrow.triangle.turn.up.right.diamond.fill")
    case let .pass(knownIssueCount):
      if knownIssueCount > 0 {
        ("\u{100882}", "minus.diamond.fill")
      } else {
        ("\u{10105B}", "checkmark.diamond.fill")
      }
    case .fail:
      ("\u{100884}", "xmark.diamond.fill")
    case .difference:
      ("\u{10017A}", "plus.forwardslash.minus")
    case .warning:
      ("\u{1001FF}", "exclamationmark.triangle.fill")
    case .details:
      ("\u{100135}", "arrow.turn.down.right")
    case .attachment:
      ("\u{100237}", "doc")
    case let .custom(_, _, _, sfSymbolCharacter, sfSymbolName, _):
      (sfSymbolCharacter, sfSymbolName)
    }
  }

#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
  /// The SF&nbsp;Symbols character corresponding to this instance.
  ///
  /// - Important: This character only renders as an [SF&nbsp;Symbol](https://developer.apple.com/sf-symbols/)
  ///   if the user has the SF&nbsp;Symbols app installed. Developers should
  ///   generally use ``sfSymbolName`` instead.
  public var sfSymbolCharacter: Character {
    _sfSymbolInfo.privateUseAreaCharacter
  }
#endif

  /// The name of the SF&nbsp;Symbol to use to represent this instance.
  ///
  /// Each instance of this type has a corresponding
  /// [SF&nbsp;Symbol](https://developer.apple.com/sf-symbols/) that can be used
  /// to represent it in a user interface. SF&nbsp;Symbols are only available on
  /// Apple platforms.
  public var sfSymbolName: String {
    _sfSymbolInfo.name
  }
}
#endif

// MARK: - Unicode and ASCII

extension Event.Symbol {
  /// The Unicode character corresponding to this instance.
  ///
  /// Each instance of this type has a corresponding Unicode character that can
  /// be used to represent it in text-based output. The value of this property
  /// is platform-dependent.
  public var unicodeCharacter: Character {
#if os(anyAppleOS) || os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android) || os(WASI) || hasFeature(Embedded)
    switch self {
    case .default:
      // Unicode: WHITE DIAMOND
      return "\u{25C7}"
    case .skip:
      // Unicode: HEAVY ROUND-TIPPED RIGHTWARDS ARROW
      return "\u{279C}"
    case let .pass(knownIssueCount):
      if knownIssueCount > 0 {
        // Unicode: BOX DRAWINGS HEAVY HORIZONTAL
        return "\u{2501}"
      } else {
        // Unicode: HEAVY CHECK MARK
        return "\u{2714}"
      }
    case .fail:
      // Unicode: HEAVY BALLOT X
      return "\u{2718}"
    case .difference:
      // Unicode: PLUS-MINUS SIGN
      return "\u{00B1}"
    case .warning:
      // Unicode: WARNING SIGN + VARIATION SELECTOR-15 (disable emoji)
      return "\u{26A0}\u{FE0E}"
    case .details:
      // Unicode: DOWNWARDS ARROW WITH TIP RIGHTWARDS
      return "\u{21B3}"
    case .attachment:
      // TODO: decide on symbol
      // Unicode: PRINT SCREEN SYMBOL
      return "\u{2399}"
    case let .custom(unicodeCharacter, _, _, _, _, _):
      return unicodeCharacter
    }
#elseif os(Windows)
    // The default Windows console font (Consolas) has limited Unicode support,
    // so substitute some other characters that it does have.
    switch self {
    case .default:
      // Unicode: LOZENGE
      return "\u{25CA}"
    case .skip:
      // Unicode: HEAVY ROUND-TIPPED RIGHTWARDS ARROW
      return "\u{279C}"
    case let .pass(knownIssueCount):
      if knownIssueCount > 0 {
        // Unicode: HYPHEN-MINUS
        return "\u{002D}"
      } else {
        // Unicode: SQUARE ROOT
        return "\u{221A}"
      }
    case .fail:
      // Unicode: MULTIPLICATION SIGN
      return "\u{00D7}"
    case .difference:
      // Unicode: PLUS-MINUS SIGN
      return "\u{00B1}"
    case .warning:
      // Unicode: BLACK UP-POINTING TRIANGLE
      return "\u{25B2}"
    case .details:
      // Unicode: RIGHTWARDS ARROW
      return "\u{2192}"
    case .attachment:
      // TODO: decide on symbol
      // Unicode: PRINT SCREEN SYMBOL
      return "\u{2399}"
    case let .custom(_, windowsCharacter, _, _, _, _):
      return windowsCharacter
    }
#else
#warning("Platform-specific implementation missing: Unicode characters unavailable")
    return " "
#endif
  }

  /// A string containing the ASCII characters corresponding to this instance.
  ///
  /// Each instance of this type has zero or more corresponding ASCII characters
  /// that can be used to represent it in text-based output where Unicode is not
  /// supported.
  public var asciiStringValue: String {
    switch self {
    case .default:
      return "[]"
    case .skip:
      return "[SKIP]"
    case let .pass(knownIssueCount):
      if knownIssueCount > 0 {
        return "[PASS W/ISSUES]"
      } else {
        return "[PASS]"
      }
    case .fail:
      return "[FAIL]"
    case .difference:
      return "[+/-]"
    case .warning:
      return "[WARNING]"
    case .details:
      return "`->"
    case .attachment:
      return "[ATTACHMENT]"
    case let .custom(_, _, asciiCharacters, _, _, _):
      if #available(_stringInitValidatingAPI, *) {
        if let result = String(validating: asciiCharacters, as: Unicode.ASCII.self) {
          return result
        }
      } else {
        var asciiCharacters = asciiCharacters
        asciiCharacters.append(0)
        let result = asciiCharacters.withUnsafeBufferPointer { asciiCharacters in
          String.decodeCString(asciiCharacters.baseAddress!, as: Unicode.ASCII.self, repairingInvalidCodeUnits: false)?.result
        }
        if let result {
          return result
        }
      }
      return "[" + String(repeating: "?", count: max(1, asciiCharacters.count)) + "]"
    }
  }

  /// The number of ASCII characters or bytes corresponding to this instance.
  ///
  /// Each instance of this type has zero or more corresponding ASCII characters
  /// that can be used to represent it in text-based output where Unicode is not
  /// supported.
  public var asciiByteCount: Int {
    guard case let .custom(_, _, asciiCharacters, _, _, _) = self else {
      return asciiStringValue.utf8.count
    }
    return asciiCharacters.count
  }
}

// MARK: - Color

extension Event.Symbol {
  /// The color to use when rendering this instance, if any.
  public var color: Color? {
    switch self {
    case .default, .skip, .difference:
      .darkGray
    case let .pass(knownIssueCount):
      if knownIssueCount > 0 {
        .darkGray
      } else {
        .green
      }
    case .fail:
      .red
    case .warning:
      .yellow
    case .details:
      nil
    case .attachment:
      .blue
    case let .custom(_, _, _, _, _, color):
      color
    }
  }
}

// MARK: - Details arrow

extension Event.Symbol {
  /// A symbol used to represent details presented on the same line.
  ///
  /// The testing library renders this symbol as a rightwards-facing arrow.
  static var inlineDetailsArrow: Self {
    .custom(
      unicodeCharacter: "\u{2192}", // Unicode: RIGHTWARDS ARROW
      windowsCharacter: "\u{2192}", // Unicode: RIGHTWARDS ARROW
      asciiCharacters: [UInt8(ascii: "-"), UInt8(ascii: ">")],
      sfSymbolCharacter: "\u{10012B}",
      sfSymbolName: "arrow.right",
    )
  }

  /// A symbol used to represent a colored tag in console output.
  static var tagDot: Self {
    .custom(
      unicodeCharacter: "\u{25CF}", // Unicode: BLACK CIRCLE
      windowsCharacter: "\u{25CF}", // Unicode: BLACK CIRCLE
      asciiCharacters: [UInt8(ascii: "*")],
      sfSymbolCharacter: "\u{100001}",
      sfSymbolName: "circle.fill",
    )
  }
}
