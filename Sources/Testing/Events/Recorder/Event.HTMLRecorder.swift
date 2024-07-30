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
  /// them as HTML.
  @_spi(Experimental) @_spi(ForToolsIntegrationOnly)
  public struct HTMLRecorder: Sendable/*, ~Copyable*/ {
    /// A type describing options to use when writing events to a stream.
    public struct Options: Sendable {
      /// The URL of a CSS file to reference in the output HTML header.
      ///
      /// The value of this property can be any absolute or relative URL. If it
      /// is `nil`, no style sheet reference is included in the output HTML
      /// header.
      var styleSheetURL: String? {
        didSet {
          if let styleSheetURL {
            precondition(styleSheetURL.allSatisfy(\.isASCII))
          }
        }
      }
    }

    /// The options for this event recorder.
    var options = Options()

    /// The write function for this event recorder.
    var write: @Sendable (String) -> Void

    /// The underlying human-readable recorder.
    private var _humanReadableOutputRecorder = HumanReadableOutputRecorder()

    /// Initialize a new event recorder.
    ///
    /// - Parameters:
    ///   - write: A closure that writes output to its destination. The closure
    ///     may be invoked concurrently.
    ///
    /// Output from the testing library is written using `write`.
    init(options: Options = .init(), writingUsing write: @escaping @Sendable (String) -> Void) {
      self.write = write
    }
  }
}

// MARK: -

extension Event.HTMLRecorder {

}

extension Event.HTMLRecorder {
  /// Record the specified event by generating a representation of it in this
  /// instance's output format and writing it to this instance's destination.
  ///
  /// - Parameters:
  ///   - event: The event to record.
  ///   - context: The context associated with the event.
  ///
  /// - Returns: Whether any output was produced and written to this instance's
  ///   destination.
  public func record(_ event: borrowing Event, in context: borrowing Event.Context) {
    var lines = [(String, depth: Int)]()
    switch event.kind {
    case .runStarted:
      lines.append(("<!DOCTYPE html>", 0))
      lines.append(("<html>", 0))
      lines.append(("<head>", 1))
      lines.append((#"<meta charset="UTF-8">"#, 2))
      if let styleSheetURL = options.styleSheetURL {
        lines.append((#"<link rel="stylesheet" href="\#(styleSheetURL)" type="text/css">"#, 2))
      }
      lines.append(("</head>", 1))
      lines.append(("<body>", 1))
    case .runEnded:
      lines.append(("</body>", 1))
      lines.append(("</html>", 0))
    default:
      break
    }

    var buffer = ""
    for (line, depth) in lines {
      buffer += "\(String(repeating: "  ", count: depth))\(line)\n"
    }
    write(buffer)

//    let messages = _humanReadableOutputRecorder.record(event, in: context, verbosity: options.verbosity)
//    for message in messages {
//      let symbol = message.symbol?.stringValue(options: options) ?? " "
//
//      if case .details = message.symbol, options.useANSIEscapeCodes, options.ansiColorBitDepth > 1 {
//        // Special-case the detail symbol to apply grey to the entire line of
//        // text instead of just the symbol.
//        write("\(_ansiEscapeCodePrefix)90m\(symbol) \(message.stringValue)\(_resetANSIEscapeCode)\n")
//      } else {
//        let colorDots = context.test.map(\.tags).map { self.colorDots(for: $0) } ?? ""
//        write("\(symbol) \(colorDots)\(message.stringValue)\n")
//      }
//    }
//    return !messages.isEmpty
  }
}
