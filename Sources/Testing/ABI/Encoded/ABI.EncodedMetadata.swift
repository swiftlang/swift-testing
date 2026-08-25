//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_ABI_JSON_SCHEMA
@_spi(Experimental)
extension ABI {
  /// A type implementing the JSON encoding of ``Event/Metadata`` for the ABI
  /// entry point and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  ///
  /// - Warning: Metadata is not yet part of the JSON schema.
  public struct EncodedMetadata<V>: Sendable where V: ABI.Version {
    /// The name of the datum.
    var name: String

    /// The value of the datum.
    var value: String
  }
}

// MARK: - Codable, JSON.Encodable

#if !SWT_NO_CODABLE
extension ABI.EncodedMetadata: Codable {}
#endif

extension ABI.EncodedMetadata: JSON.Encodable {
  func jsonValue(in context: JSON.EncodingContext) -> JSON.Value {
    var result = [String: JSON.Value]()

    result["name"] = name.jsonValue(in: context)
    result["value"] = value.jsonValue(in: context)

    return .object(result)
  }
}

// MARK: - Conversion to/from library types

extension ABI.EncodedMetadata {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - metadata: The metadata to initialize this instance from.
  public init(encoding metadata: borrowing Event.Metadata) {
    name = metadata.name
    value = metadata.value
  }
}

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension Event.Metadata {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - metadata: The encoded metadata to initialize this instance from.
  public init?<V>(decoding metadata: ABI.EncodedMetadata<V>) {
    self.init(name: metadata.name, value: metadata.value)
  }
}
#endif
