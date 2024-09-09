//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABIv0 {
  /// A type implementing the JSON encoding of ``Backtrace`` for the ABI entry
  /// point and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedBacktrace: Sendable {
    /// A type describing a frame in the backtrace.
    struct Frame: Sendable {
      /// The address of the frame.
      var address: Backtrace.Address

      /// The name of the frame, possibly demangled, if available.
      var symbolName: String?
    }

    /// The frames in the backtrace.
    var frames: [Frame]

    init(encoding backtrace: borrowing Backtrace, in eventContext: borrowing Event.Context) {
      if let symbolicationMode = eventContext.configuration?.backtraceSymbolicationMode {
        frames = zip(backtrace.addresses, backtrace.symbolicate(symbolicationMode)).map(Frame.init)
      } else {
        frames = backtrace.addresses.map { Frame(address: $0) }
      }
    }
  }
}

// MARK: - Codable

extension ABIv0.EncodedBacktrace: Codable {
  func encode(to encoder: any Encoder) throws {
    try frames.encode(to: encoder)
  }

  init(from decoder: any Decoder) throws {
    self.frames = try [Frame](from: decoder)
  }
}

extension ABIv0.EncodedBacktrace.Frame: Codable {}
