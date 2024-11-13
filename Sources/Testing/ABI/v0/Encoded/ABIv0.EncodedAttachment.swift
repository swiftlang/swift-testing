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
  /// A type implementing the JSON encoding of ``Attachment`` for the ABI entry
  /// point and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  ///
  /// - Warning: Attachments are not yet part of the JSON schema.
  struct EncodedAttachment: Sendable {
    /// The path where the attachment was written.
    var path: String?

    init(encoding attachment: borrowing Attachment<AnyAttachable>, in eventContext: borrowing Event.Context) {
      path = attachment.fileSystemPath
    }
  }
}

// MARK: - Codable

extension ABIv0.EncodedAttachment: Codable {}
