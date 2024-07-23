//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A protocol describing a message logged with `print()` or another logging
/// system.
@_spi(ForToolsIntegrationOnly)
public protocol LoggedMessage: Sendable {
  /// The human-readable, unformatted text associated with this message.
  var text: String { get }
}

// MARK: - print()

/// An override of ``/Swift/print(_:separator:terminator:)`` from the Swift
/// standard library that also generates a test event.
@_spi(Experimental)
@_documentation(visibility: private)
public func print(
  _ items: Any...,
  separator: String = " ",
  terminator: String = "\n"
) {
  let output = items.lazy
    .map(String.init(describing:))
    .joined(separator: separator)

  Event.post(.messageLogged(PrintedMessage(text: output)))
  Swift.print(output, terminator: terminator)
}

/// A type describing a message logged with
/// ``/Swift/print(_:separator:terminator:)``.
@_spi(ForToolsIntegrationOnly)
public struct PrintedMessage: LoggedMessage {
  public var text: String
}

// MARK: - debugPrint()

/// An override of ``/Swift/debugPrint(_:separator:terminator:)`` from the Swift
/// standard library that also generates a test event.
@_spi(Experimental)
@_documentation(visibility: private)
public func debugPrint(
  _ items: Any...,
  separator: String = " ",
  terminator: String = "\n"
) {
  let output = items.lazy
    .map(String.init(reflecting:))
    .joined(separator: separator)

  Event.post(.messageLogged(DebugPrintedMessage(text: output)))
  Swift.debugPrint(output, terminator: terminator)
}

/// A type describing a message logged with
/// ``/Swift/debugPrint(_:separator:terminator:)``.
@_spi(ForToolsIntegrationOnly)
public struct DebugPrintedMessage: LoggedMessage {
  public var text: String
}
