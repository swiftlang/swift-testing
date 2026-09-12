//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_ABI_JSON_SCHEMA
#if SWT_NO_CODABLE
#error("Platform-specific misconfiguration: support for the ABI JSON schema requires support for 'Codable'")
#endif

extension ABI {
  /// A type implementing the JSON encoding of records for the ABI entry point
  /// and event stream output.
  ///
  /// You can use this type and its conformance to [`Codable`](https://developer.apple.com/documentation/swift/codable),
  /// when integrating the testing library with development tools. It is not
  /// part of the testing library's public interface.
  public struct Record<V>: Sendable where V: ABI.Version {
    /// An enumeration describing the various kinds of record.
    public enum Kind: Sendable {
      /// A test record.
      case test(EncodedTest<V>)

      /// An event record.
      case event(EncodedEvent<V>)

      /// Some metadata regarding the test run, the current environment, etc.
      ///
      /// - Warning: Metadata is not yet part of the JSON schema.
      @_spi(Experimental)
      case metadata(EncodedMetadata<V>)
    }

    /// The kind of record.
    public internal(set) var kind: Kind

    public init(encoding test: borrowing EncodedTest<V>) {
      kind = .test(copy test)
    }

    public init(encoding event: borrowing EncodedEvent<V>) {
      kind = .event(copy event)
    }

    public init?(encoding metadata: borrowing EncodedMetadata<V>) {
      guard V.includesExperimentalFields else {
        return nil
      }
      kind = .metadata(copy metadata)
    }
  }
}

// MARK: -

extension ABI.Record {
  init(encoding test: borrowing Test) {
    let test = ABI.EncodedTest<V>(encoding: test)
    self.init(encoding: test)
  }

  init?(encoding event: borrowing Event, in eventContext: borrowing Event.Context, messages: borrowing [Event.HumanReadableOutputRecorder.Message] = []) {
    switch event.kind {
    case .testDiscovered:
      guard let test = eventContext.test else {
        return nil
      }
      self.init(encoding: test)
    case let .metadataRecorded(metadata):
      self.init(encoding: metadata)
    default:
      guard let event = ABI.EncodedEvent<V>(encoding: event, in: eventContext, messages: messages) else {
        return nil
      }
      if !V.includesExperimentalFields && event.kind.rawValue.first == "_" {
        // Don't encode experimental event kinds.
        return nil
      }
      self.init(encoding: event)
    }
  }

  init?(encoding metadata: borrowing Event.Metadata) {
    let metadata = ABI.EncodedMetadata<V>(encoding: metadata)
    self.init(encoding: metadata)
  }
}

// MARK: - Codable

extension ABI.Record: Codable {
  private enum CodingKeys: String, CodingKey {
    case version
    case kind
    case payload
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(V.versionNumber, forKey: .version)
    switch kind {
    case let .test(test):
      try container.encode("test", forKey: .kind)
      try container.encode(test, forKey: .payload)
    case let .event(event):
      try container.encode("event", forKey: .kind)
      try container.encode(event, forKey: .payload)
    case let .metadata(metadata) where V.includesExperimentalFields:
      try container.encode("_metadata", forKey: .kind)
      try container.encode(metadata, forKey: .payload)
    default:
      throw EncodingError.invalidValue(
        kind,
        EncodingError.Context(
          codingPath: encoder.codingPath + CollectionOfOne(CodingKeys.payload as any CodingKey),
          debugDescription: "Record version \(V.versionNumber) does not support encoding records of kind \(kind)."
        )
      )
    }
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    func validateVersionNumber(_ versionNumber: VersionNumber) throws {
      if versionNumber == V.versionNumber {
        return
      }
      // Allow for alternate version numbers if they correspond to the expected
      // record version (e.g. "1.2.3" might map to `v1_2_0` without a problem.)
      if ABI.version(forVersionNumber: versionNumber) == V.self {
        return
      }
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath + CollectionOfOne(CodingKeys.version as any CodingKey),
          debugDescription: "Unexpected record version \(versionNumber) (expected \(V.versionNumber))."
        )
      )
    }
    let versionNumber = try container.decode(VersionNumber.self, forKey: .version)
    try validateVersionNumber(versionNumber)

    switch try container.decode(String.self, forKey: .kind) {
    case "test":
      let test = try container.decode(ABI.EncodedTest<V>.self, forKey: .payload)
      kind = .test(test)
    case "event":
      let event = try container.decode(ABI.EncodedEvent<V>.self, forKey: .payload)
      kind = .event(event)
    case "_metadata" where V.includesExperimentalFields:
      let metadata = try container.decode(ABI.EncodedMetadata<V>.self, forKey: .payload)
      kind = .metadata(metadata)
    case let kind:
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath + CollectionOfOne(CodingKeys.kind as any CodingKey),
          debugDescription: "Unrecognized record kind '\(kind)'"
        )
      )
    }
  }
}
#endif
