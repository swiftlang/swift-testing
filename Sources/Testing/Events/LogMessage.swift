//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A message that was logged during testing.
@_spi(Experimental)
public protocol LogMessage: Sendable {
  /// The type of a logged message's string representation.
  associatedtype StringValue: Sendable, StringProtocol = String

  /// The string representation of the logged message.
  var stringValue: StringValue { get }

  /// A type describing the different severity levels that the corresponding
  /// logging system uses.
  ///
  /// If this type equals [`Never`](https://developer.apple.com/documentation/swift/never),
  /// then the corresponding logging system does not track severity levels for
  /// logged messages.
  associatedtype Severity: Sendable, Equatable, Comparable = Never

  /// The severity of the logged message.
  ///
  /// If the value of this property is `nil`, the logging system did not track
  /// this message's severity level.
  var severity: Severity? { get }
}

extension LogMessage where Severity == Never {
  public var severity: Severity? {
    nil
  }
}

/// Start listening for messages logged via all known logging systems.
func installAllLogMessageHooks() {
  PrintedMessage.installPlaygroundPrintHook
}

// MARK: - print() and debugPrint() support

/// A message that was logged during testing.
fileprivate struct PrintedMessage: Sendable, LogMessage {
  var stringValue: String
}

extension PrintedMessage {
  /// A redeclaration of `_playgroundPrintHook` from the Swift standard library
  /// so as to avoid diagnostics about it being concurrency-unsafe.
  private static nonisolated(unsafe) var _playgroundPrintHook: ((String) -> Void)? {
    @_silgen_name("$ss20_playgroundPrintHookySScSgvg") get
    @_silgen_name("$ss20_playgroundPrintHookySScSgvs") set
  }

  /// Install a hook in `print()` and `debugPrint()`.
  static let installPlaygroundPrintHook: Void = {
    _playgroundPrintHook = { stringValue in
      var stringValue = stringValue[...]
      let lastNonNewlineCharacterIndex = stringValue.lastIndex { !$0.isNewline }
      if let lastNonNewlineCharacterIndex {
        stringValue = stringValue[...lastNonNewlineCharacterIndex]
      }
      let message = Self(stringValue: String(stringValue))
      Event.post(.messageLogged(message))
    }
  }()
}
