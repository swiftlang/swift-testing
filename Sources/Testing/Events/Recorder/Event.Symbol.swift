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
    ///   - knownIssueCount: The number of known issues encountered by the end
    ///     of the test.
    case pass(knownIssueCount: Int = 0)

    /// The symbol to use when a test fails.
    case fail

    /// The symbol to use when an expectation includes a difference description.
    case difference

    /// A warning or caution symbol to use when the developer should be aware of
    /// some condition.
    case warning

    /// The symbol to use when presenting details about an event to the user.
    case details
  }
}

#if SWT_TARGET_OS_APPLE
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
        ("\u{100884}", "xmark.diamond.fill")
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
    }
  }

#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
  /// The SF&nbsp;Symbols character corresponding to this instance.
  ///
  /// This property is not part of the public interface of the testing library.
  /// Developers should use ``sfSymbolName`` instead.
  var sfSymbolCharacter: Character {
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

// MARK: - Unicode

extension Event.Symbol {
  /// The Unicode character corresponding to this instance.
  ///
  /// Each instance of this type has a corresponding Unicode character that can
  /// be used to represent it in text-based output. The value of this property
  /// is platform-dependent.
  public var unicodeCharacter: Character {
#if SWT_TARGET_OS_APPLE || os(Linux) || os(Android) || os(WASI)
    switch self {
    case .default:
      // Unicode: WHITE DIAMOND
      return "\u{25C7}"
    case .skip:
      // Unicode: HEAVY BALLOT X
      return "\u{2718}"
    case let .pass(knownIssueCount):
      if knownIssueCount > 0 {
        // Unicode: HEAVY BALLOT X
        return "\u{2718}"
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
    }
#elseif os(Windows)
    // The default Windows console font (Consolas) has limited Unicode support,
    // so substitute some other characters that it does have.
    switch self {
    case .default:
      // Unicode: LOZENGE
      return "\u{25CA}"
    case .skip:
      // Unicode: MULTIPLICATION SIGN
      return "\u{00D7}"
    case let .pass(knownIssueCount):
      if knownIssueCount > 0 {
        // Unicode: MULTIPLICATION SIGN
        return "\u{00D7}"
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
    }
#else
#warning("Platform-specific implementation missing: Unicode characters unavailable")
    return " "
#endif
  }
}

// MARK: - Codable

extension Event.Symbol: Codable {}
