//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

extension ABI {
  /// A type implementing the JSON encoding of ``Error`` for the ABI entry point
  /// and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  ///
  /// - Warning: Errors are not yet part of the JSON schema.
  @_spi(Experimental)
  public struct EncodedError<V>: Sendable where V: ABI.Version {
    /// The error's description.
    ///
    /// The value of this property may be `nil` if the error originated in a
    /// context other than Swift or Objective-C (where errors may not have
    /// associated descriptions).
    var description: String?

    /// The domain of the error.
    ///
    /// The value of this property may be `nil` if the error originated in a
    /// context other than Swift or Objective-C (where errors may not have
    /// associated domain strings).
    var domain: String?

    /// The code of the error.
    var code: Int

    // TODO: userInfo (partial) encoding
  }
}

// MARK: - Error

extension ABI.EncodedError: Error {
  /// The domain of decoded errors that did not specify a domain of their own.
  public static var unknownDomain: String {
    "<unknown>"
  }

  public var _domain: String {
    domain ?? Self.unknownDomain
  }

  public var _code: Int {
    code
  }

  public var _userInfo: AnyObject? {
    // TODO: userInfo (partial) encoding
    nil
  }
}

#if !SWT_NO_CODABLE
// MARK: - Codable

extension ABI.EncodedError: Codable {}
#endif

// MARK: - CustomTestStringConvertible

extension ABI.EncodedError: CustomTestStringConvertible {
  public var testDescription: String {
    if let description {
      return description
    } else if let domain {
      return "\(domain) error \(code)"
    }
    return "error \(code)"
  }
}

// MARK: - Conversion to/from library types

extension ABI.EncodedError {
  public init(encoding error: some Error) {
    let description = String(describingForTest: error)
    if !description.isEmpty {
      self.description = description
    }
    let domain = error._domain
    if domain != Self.unknownDomain {
      self.domain = domain
    }
    code = error._code
  }
}

// Error.init(decoding:) is not implemented here because a) Error is a protocol
// and cannot be instantiated directly, and b) ABI.EncodedError already conforms
// to Error, so a cast is generally not necessary.
