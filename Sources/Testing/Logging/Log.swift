//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental)
extension Test {
  /// A type representing the message log associated with the current process.
  ///
  /// You do not create instances of this type. Instead, record log messages by
  /// calling ``record(_:sourceLocation:)`` or (on Apple platforms) by logging
  /// messages to an instance of [`os.Logger`](https://developer.apple.com/documentation/os/logger).
  public struct Log: Sendable {
    /// A message from the message log associated with the current process.
    ///
    /// You do not typically create instances of this type. Instead, record log
    /// messages by calling ``record(_:sourceLocation:)`` or (on Apple
    /// platforms) by logging messages to an instance of [`os.Logger`](https://developer.apple.com/documentation/os/logger).
    public struct Message: Sendable {
      /// A string representation of the message.
      public var stringValue: String

      /// A ``SourceContext`` indicating where and how this message was logged.
      @_spi(ForToolsIntegrationOnly)
      public var sourceContext: SourceContext = SourceContext(backtrace: nil, sourceLocation: nil)

      /// The location in source where this message was logged, if available.
      public var sourceLocation: SourceLocation? {
        get {
          sourceContext.sourceLocation
        }
        set {
          sourceContext.sourceLocation = newValue
        }
      }
    }

    /// Record a given message in the current process' message log.
    ///
    /// - Parameters:
    ///   - message: The message to record.
    ///   - sourceLocation: The source location of the message.
    ///
    /// Call this function to include the given message in the output of your
    /// test run.
    public static func record(_ message: consuming Message, sourceLocation: SourceLocation = #_sourceLocation) {
      let sourceContext = SourceContext(
        backtrace: message.sourceContext.backtrace,
        sourceLocation: message.sourceContext.sourceLocation ?? sourceLocation
      )
      record(message.stringValue, severity: nil, sourceContext: sourceContext)
    }

    /// Record a given message in the current process' message log.
    ///
    /// - Parameters:
    ///   - stringValue: The string value of the message to record.
    ///   - severity: The severity of the message, if applicable.
    ///   - sourceContext: The source context of the message.
    ///
    /// This function acts as a bottleneck for recording messages from different
    /// sources and is responsible for generating a corresponding ``Issue`` or
    /// ``Event`` instance.
    ///
    /// Test authors can call ``record(_:sourceLocation:)`` to record a message.
    static func record(_ stringValue: String, severity: Issue.Severity?, sourceContext: @autoclosure () -> SourceContext) {
      if let severity {
        let issue = Issue(kind: .unconditional, severity: severity, comments: [Comment(rawValue: stringValue)], sourceContext: sourceContext())
        issue.record()
      } else if Test.current == nil {
        // If the message wasn't associated with a test, only log it if it has
        // non-default severity so as to avoid a poor signal-to-noise ratio.
        return
      } else {
        let message = Message(stringValue: stringValue, sourceContext: sourceContext())
        Event.post(.messageLogged(message))
      }
    }

    /// Start listening for messages recorded in external logging systems.
    ///
    /// ``Runner`` calls this function when it starts a test run. Calling this
    /// function more than once has no effect.
    static func startListening() {
#if SWT_TARGET_OS_APPLE && canImport(os.log)
      startListeningForOSLogMessages()
#endif
    }
  }
}

// MARK: - ExpressibleByStringLiteral, CustomStringConvertible

@_spi(Experimental)
extension Test.Log.Message: ExpressibleByStringLiteral, CustomStringConvertible {
  public init(stringLiteral: String) {
    self.init(stringValue: stringLiteral)
  }

  public var description: String {
    stringValue
  }
}

// MARK: - ExpressibleByStringInterpolation

@_spi(Experimental)
extension Test.Log.Message: ExpressibleByStringInterpolation {
  public init(stringInterpolation: StringInterpolation) {
    self.init(stringValue: stringInterpolation.rawValue)
  }

  // Use the same interpolation logic as ``Comment``.
  public typealias StringInterpolation = Comment.StringInterpolation
}
