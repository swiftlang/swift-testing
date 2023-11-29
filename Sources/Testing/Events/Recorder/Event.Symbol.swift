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

#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
    /// The SF Symbols character corresponding to this instance.
    var sfSymbolCharacter: Character {
      switch self {
      case .default:
        // SF Symbol: diamond
        return "\u{1007C8}"
      case .skip:
        // SF Symbol: arrow.triangle.turn.up.right.diamond.fill
        return "\u{10065F}"
      case let .pass(knownIssueCount):
        if knownIssueCount > 0 {
          // SF Symbol: xmark.diamond.fill
          return "\u{100884}"
        } else {
          // SF Symbol: checkmark.diamond.fill
          return "\u{10105B}"
        }
      case .fail:
        // SF Symbol: xmark.diamond.fill
        return "\u{100884}"
      case .difference:
        // SF Symbol: plus.forwardslash.minus
        return "\u{10017A}"
      case .warning:
        // SF Symbol: exclamationmark.triangle.fill
        return "\u{1001FF}"
      case .details:
        // SF Symbol: arrow.turn.down.right
        return "\u{100135}"
      }
    }
#endif

    /// The Unicode character corresponding to this instance.
    var unicodeCharacter: Character {
#if SWT_TARGET_OS_APPLE || os(Linux)
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
      // The default Windows console font (Consolas) has limited Unicode
      // support, so substitute some other characters that it does have.
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
        // Unicode: EXCLAMATION MARK
        return "\u{0021}"
      case .details:
        // Unicode: GREATER-THAN SIGN
        return "\u{003E}"
      }
#else
#warning("Platform-specific implementation missing: Unicode characters unavailable")
      return " "
#endif
    }
  }
}

// MARK: - Codable

extension Event.Symbol: Codable {}
