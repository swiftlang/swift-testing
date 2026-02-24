//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation)
private import Foundation
#endif

extension ABI {
  /// A type implementing the JSON encoding of ``Attachment`` for the ABI entry
  /// point and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedAttachment<V>: Sendable where V: ABI.Version {
    /// The different kinds of encoded attachment.
    fileprivate enum Kind: Sendable {
      /// The attachment has already been saved to disk and we have its local
      /// file system path.
      case savedAtPath(String)

      /// The attachment is stored in memory and we have its serialized form.
      case inMemory(Bytes)

      /// The attachment has not been saved nor serialized yet and we still have
      /// it as an attachable value.
      case abstract(Attachment<AnyAttachable>)
    }

    /// The kind of encoded attachment.
    fileprivate var kind: Kind

    /// The preferred name of the attachment.
    ///
    /// - Warning: Attachments' preferred names are not yet part of the JSON
    ///   schema.
    var _preferredName: String?

    init(encoding attachment: borrowing Attachment<AnyAttachable>, in eventContext: borrowing Event.Context) {
      if let path = attachment.fileSystemPath {
        kind = .savedAtPath(path)
      } else {
        kind = .abstract(copy attachment)
      }

      if V.includesExperimentalFields {
        _preferredName = attachment.preferredName
      }
    }

    /// The path where the attachment was written.
    var path: String? {
      if case let .savedAtPath(path) = kind {
        return path
      }
      return nil
    }

    /// A structure representing the bytes of an attachment.
    struct Bytes: Sendable, RawRepresentable {
      var rawValue: [UInt8]
    }

    /// The raw content of the attachment, if available.
    ///
    /// The value of this property is set if the attachment was not first saved
    /// to a file. It may also be `nil` if an error occurred while trying to get
    /// the original attachment's serialized representation.
    ///
    /// - Warning: Inline attachment content is not yet part of the JSON schema.
    var _bytes: Bytes? {
      switch kind {
      case let .inMemory(bytes):
        return bytes
      case let .abstract(attachment):
        return try? attachment.withUnsafeBytes { Bytes(rawValue: Array($0)) }
      default:
        return nil
      }
    }
  }
}

// MARK: - Codable

extension ABI.EncodedAttachment: Codable {
  private enum CodingKeys: String, CodingKey {
  case path
  case preferredName = "_preferredName"
  case bytes = "_bytes"
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(path, forKey: .path)
    if V.includesExperimentalFields {
      try container.encodeIfPresent(_bytes, forKey: .bytes)
      try container.encodeIfPresent(_preferredName, forKey: .preferredName)
    }
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let path = try container.decodeIfPresent(String.self, forKey: .path) {
      kind = .savedAtPath(path)
    } else if V.includesExperimentalFields,
              let bytes = try container.decodeIfPresent(Bytes.self, forKey: .bytes) {
      kind = .inMemory(bytes)
    } else {
      throw DecodingError.valueNotFound(
        String.self,
        DecodingError.Context(
          codingPath: decoder.codingPath + [CodingKeys.path],
          debugDescription: "Encoded attachment did not include any persistent representation."
        )
      )
    }
    if V.includesExperimentalFields {
      _preferredName = try container.decodeIfPresent(String.self, forKey: .preferredName)
    }
  }
}

extension ABI.EncodedAttachment.Bytes: Codable {
  func encode(to encoder: any Encoder) throws {
#if canImport(Foundation)
    // If possible, encode this structure as Base64 data.
    try rawValue.withUnsafeBytes { rawValue in
      let data = Data(bytesNoCopy: .init(mutating: rawValue.baseAddress!), count: rawValue.count, deallocator: .none)
      var container = encoder.singleValueContainer()
      try container.encode(data)
    }
#else
    // Otherwise, it's an array of integers.
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
#endif
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()

#if canImport(Foundation)
    // If possible, decode a whole Foundation Data object.
    if let data = try? container.decode(Data.self) {
      self.init(rawValue: [UInt8](data))
      return
    }
#endif

    // Fall back to trying to decode an array of integers.
    let bytes = try container.decode([UInt8].self)
    self.init(rawValue: bytes)
  }
}

// MARK: - Attachable

extension ABI.EncodedAttachment: Attachable {
  var estimatedAttachmentByteCount: Int? {
    switch kind {
    case .savedAtPath:
      return nil
    case let .inMemory(bytes):
      return bytes.rawValue.count
    case let .abstract(attachment):
      return attachment.attachableValue.estimatedAttachmentByteCount
    }
  }

  /// An error type that is thrown when ``ABI/EncodedAttachment`` cannot satisfy
  /// a request for the underlying attachment's bytes.
  fileprivate struct BytesUnavailableError: Error {}

  borrowing func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    switch kind {
    case let .savedAtPath(path):
#if !SWT_NO_FILE_IO
#if canImport(Foundation)
      // Leverage Foundation's file-mapping logic since we're using Data anyway.
      let url = URL(fileURLWithPath: path, isDirectory: false)
      let bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
#else
      let fileHandle = try FileHandle(forReadingAtPath: path)
      let bytes = try fileHandle.readToEnd()
#endif
      return try bytes.withUnsafeBytes(body)
#else
      // Cannot read the attachment from disk on this platform.
      throw BytesUnavailableError()
#endif
    case let .inMemory(bytes):
      return try bytes.rawValue.withUnsafeBytes(body)
    case let .abstract(attachment):
      return try attachment.withUnsafeBytes(body)
    }
  }

  borrowing func preferredName(for attachment: borrowing Attachment<Self>, basedOn suggestedName: String) -> String {
    _preferredName ?? suggestedName
  }
}

extension ABI.EncodedAttachment.BytesUnavailableError: CustomStringConvertible {
  var description: String {
    "The attachment's content could not be deserialized."
  }
}
