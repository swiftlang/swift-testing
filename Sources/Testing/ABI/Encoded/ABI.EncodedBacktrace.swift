//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABI {
  /// A type implementing the JSON encoding of ``Backtrace`` for the ABI entry
  /// point and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  ///
  /// - Warning: Backtraces are not yet part of the JSON schema.
  struct EncodedBacktrace<V>: Sendable where V: ABI.Version {
    /// The frames in the backtrace.
    var symbolicatedAddresses: [Backtrace.SymbolicatedAddress]

    init(encoding backtrace: borrowing Backtrace, in eventContext: borrowing Event.Context) {
      if let symbolicationMode = eventContext.configuration?.backtraceSymbolicationMode {
        symbolicatedAddresses = backtrace.symbolicate(symbolicationMode)
      } else {
        symbolicatedAddresses = backtrace.addresses.map { Backtrace.SymbolicatedAddress(address: $0) }
      }
    }
  }
}

// MARK: - Decodable

extension ABI.EncodedBacktrace: Decodable {
  init(from decoder: any Decoder) throws {
    self.symbolicatedAddresses = try [Backtrace.SymbolicatedAddress](from: decoder)
  }
}

// MARK: - JSON.Serializable

extension ABI.EncodedBacktrace: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    symbolicatedAddresses.makeJSONValue()
  }
}

extension Backtrace.SymbolicatedAddress: JSON.Serializable {
  func makeJSONValue() -> JSON.Value {
    var dict = [
      "address": address.makeJSONValue()
    ]

    if let offset {
      dict["offset"] = offset.makeJSONValue()
    }
    if let symbolName {
      dict["symbolName"] = symbolName.makeJSONValue()
    }

    return .object(dict)
  }
}
