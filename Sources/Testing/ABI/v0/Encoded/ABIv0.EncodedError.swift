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
  /// A type implementing the JSON encoding of ``Error`` for the ABI entry point
  /// and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  ///
  /// - Warning: Errors are not yet part of the JSON schema.
  struct EncodedError: Sendable {
    /// The error's description
    var description: String

    /// The domain of the error.
    var domain: String

    /// The code of the error.
    var code: Int

    // TODO: userInfo (partial) encoding

    init(encoding error: some Error, in eventContext: borrowing Event.Context) {
      description = String(describingForTest: error)
      domain = error._domain
      code = error._code
    }
  }
}

// MARK: - Error, CustomNSError

extension ABIv0.EncodedError: Error {
  var _domain: String {
    domain
  }

  var _code: Int {
    code
  }

  var _userInfo: AnyObject? {
    // TODO: userInfo (partial) encoding
    nil
  }
}

// MARK: - Codable

extension ABIv0.EncodedError: Codable {}

// MARK: - CustomTestStringConvertible

extension ABIv0.EncodedError: CustomTestStringConvertible {
  var testDescription: String {
    description
  }
}
