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
  /// A type implementing the JSON encoding of records for the ABI entry point
  /// and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct Record: Sendable {
    /// The version of this record.
    ///
    /// The value of this property corresponds to the ABI version i.e. `0`.
    var version = 0

    /// An enumeration describing the various kinds of record.
    enum Kind: Sendable {
      /// A test record.
      case test(EncodedTest)

      /// An event record.
      case event(EncodedEvent)
    }

    /// The kind of record.
    var kind: Kind

    init(encoding test: borrowing Test) {
      kind = .test(EncodedTest(encoding: test))
    }

    init?(encoding event: borrowing Event, in eventContext: borrowing Event.Context, messages: borrowing [Event.HumanReadableOutputRecorder.Message]) {
      guard let event = EncodedEvent(encoding: event, in: eventContext, messages: messages) else {
        return nil
      }
      kind = .event(event)
    }
  }
}

// MARK: - Codable

extension ABIv0.Record: Codable {
  private enum CodingKeys: String, CodingKey {
    case version
    case kind
    case payload
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    switch kind {
    case let .test(test):
      try container.encode("test", forKey: .kind)
      try container.encode(test, forKey: .payload)
    case let .event(event):
      try container.encode("event", forKey: .kind)
      try container.encode(event, forKey: .payload)
    }
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decode(Int.self, forKey: .version)
    switch try container.decode(String.self, forKey: .kind) {
    case "test":
      let test = try container.decode(ABIv0.EncodedTest.self, forKey: .payload)
      kind = .test(test)
    case "event":
      let event = try container.decode(ABIv0.EncodedEvent.self, forKey: .payload)
      kind = .event(event)
    case let kind:
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unrecognized record kind '\(kind)'"))
    }
  }
}
