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
    case passWithWarnings

    /// The symbol to use when a test fails.
    case fail

    /// The symbol to use when an expectation includes a difference description.
    case difference

    /// A warning or caution symbol to use when the developer should be aware of
    /// some condition.
    case warning

    /// The symbol to use when presenting details about an event to the user.
    case details

    /// The symbol to use when describing an instance of ``Attachment``.
    case attachment
  }
}

#if SWT_TARGET_OS_APPLE
// MARK: - SF Symbols

extension Event.Symbol {
  /// The SF&nbsp;Symbols character and name corresponding to this instance.
  private var _sfSymbolInfo: (privateUseAreaCharacter: Character, name: String) {
    switch self {
    case .default:
      ("􀊕", "play.circle")  // running: play.circle (teal)
    case .skip:
      ("􀺅", "forward.circle")  // skip: forward.circle (purple)
    case let .pass(knownIssueCount):
      if knownIssueCount > 0 {
        ("􀀲", "x.circle")  // pass with known issues: x.circle (gray)
      } else {
        ("􀁢", "checkmark.circle")  // pass: checkmark.circle (green)
      }
    case .passWithWarnings:
      ("􀁜", "questionmark.circle")  // pass with warnings: questionmark.circle (yellow)
    case .fail:
      ("􀀲", "x.circle")  // fail: x.circle (red)
    case .difference:
      ("􂫃", "notequal.circle")  // difference: notequal.circle (brown)
    case .warning:
      ("􀁞", "exclamationmark.circle")  // warning: exclamationmark.circle (orange)
    case .details:
      ("􀂄", "arrow.up.right.circle")  // details: arrow.up.right.circle (blue)
    case .attachment:
      ("􀒔", "paperclip.circle")  // attachment: paperclip.circle (gray)
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
#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android) || os(WASI)
    switch self {
    case .default:
      // Unicode: WHITE DIAMOND
      return "\u{25C7}"
    case .skip:
      // Unicode: HEAVY ROUND-TIPPED RIGHTWARDS ARROW
      return "\u{279C}"
    case let .pass(knownIssueCount):
      if knownIssueCount > 0 {
        // Unicode: HEAVY BALLOT X
        return "\u{2718}"
      } else {
        // Unicode: HEAVY CHECK MARK
        return "\u{2714}"
      }
    case .passWithWarnings:
      // Unicode: QUESTION MARK
      return "\u{003F}"
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
        // Unicode: MULTIPLICATION SIGN
        return "\u{00D7}"
      } else {
        // Unicode: SQUARE ROOT
        return "\u{221A}"
      }
    case .passWithWarnings:
      // Unicode: QUESTION MARK
      return "\u{003F}"
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
    }
#else
#warning("Platform-specific implementation missing: Unicode characters unavailable")
    return " "
#endif
  }
}

// MARK: - Codable

extension Event.Symbol: Codable {}
