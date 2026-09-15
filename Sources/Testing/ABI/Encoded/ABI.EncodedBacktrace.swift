//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_ABI_JSON_SCHEMA
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
#if !SWT_NO_BACKTRACE_SYMBOLICATION
    /// The frames in the backtrace.
    var symbolicatedAddresses: [Backtrace.SymbolicatedAddress]
#else
    /// The frames in the backtrace.
    var addresses: [Backtrace.Address]
#endif
    init(encoding backtrace: borrowing Backtrace, in eventContext: borrowing Event.Context) {
#if !SWT_NO_BACKTRACE_SYMBOLICATION
      if let symbolicationMode = eventContext.configuration?.backtraceSymbolicationMode {
        symbolicatedAddresses = backtrace.symbolicate(symbolicationMode)
      } else {
        symbolicatedAddresses = backtrace.addresses.map { Backtrace.SymbolicatedAddress(address: $0) }
      }
#else
      addresses = backtrace.addresses
#endif
    }
  }
}

#if !SWT_NO_CODABLE
// MARK: - Codable

extension ABI.EncodedBacktrace: Codable {
  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
#if !SWT_NO_BACKTRACE_SYMBOLICATION
    try container.encode(symbolicatedAddresses)
#else
    try container.encode(addresses)
#endif
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
#if !SWT_NO_BACKTRACE_SYMBOLICATION
    symbolicatedAddresses = try container.decode([Backtrace.SymbolicatedAddress].self)
#else
    addresses = try container.decode([Backtrace.Address].self)
#endif
  }
}
#endif
#endif
