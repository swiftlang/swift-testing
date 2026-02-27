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
  /// You can use this type and its conformance to [`Codable`](https://developer.apple.com/documentation/swift/codable),
  /// when integrating the testing library with development tools. It is not
  /// part of the testing library's public interface.
  public struct EncodedAttachment<V>: Sendable where V: ABI.Version {
    /// The different kinds of encoded attachment.
    private enum _Kind: Sendable {
      /// The attachment has already been saved to disk and we have its local
      /// file system path.
      case savedAtPath(String)

      /// The attachment is stored in memory and we have its serialized form.
      case inMemory([UInt8])

      /// The attachment has not been saved nor serialized yet and we still have
      /// it as an attachable value.
      case abstract(Attachment<AnyAttachable>)

      /// An error occurred when the attachment was encoded that prevented it
      /// from being properly serialized.
      case error(ABI.EncodedError<V>)
    }

    /// The kind of encoded attachment.
    private var _kind: _Kind

    /// The preferred name of the attachment.
    ///
    /// - Warning: Attachments' preferred names are not yet part of the JSON
    ///   schema.
    var _preferredName: String?

    public init(encoding attachment: borrowing Attachment<AnyAttachable>) {
      if let path = attachment.fileSystemPath {
        _kind = .savedAtPath(path)
      } else {
        _kind = .abstract(copy attachment)
      }

      if V.includesExperimentalFields {
        _preferredName = attachment.preferredName
      }
    }

    public init(encoding attachment: borrowing Attachment<some Attachable & Sendable & ~Copyable>) {
      let attachmentCopy = Attachment<AnyAttachable>(copy attachment)
      self.init(encoding: attachmentCopy)
    }
  }
}

// MARK: - Codable

extension ABI.EncodedAttachment: Codable {
  private enum CodingKeys: String, CodingKey {
    case path
    case preferredName = "_preferredName"
    case bytes = "_bytes"
    case error = "_error"
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    func encodeBytes(_ bytes: UnsafeRawBufferPointer) throws {
#if canImport(Foundation)
      // If possible, encode this structure as Base64 data.
      try bytes.withUnsafeBytes { bytes in
        let data = Data(bytesNoCopy: .init(mutating: bytes.baseAddress!), count: bytes.count, deallocator: .none)
        try container.encode(data, forKey: .bytes)
      }
#else
      // Otherwise, it's an array of integers.
      try container.encode(bytes, forKey: .bytes)
#endif
    }

    switch _kind {
    case let .savedAtPath(path):
      try container.encode(path, forKey: .path)
    case let .abstract(attachment):
      if V.includesExperimentalFields {
        var errorWhileEncoding: (any Error)?
        do {
          try attachment.withUnsafeBytes { bytes in
            do {
              try encodeBytes(bytes)
            } catch {
              // An error occurred during encoding rather than coming from the
              // attachment itself. Preserve it and throw it before returning.
              errorWhileEncoding = error
            }
          }
        } catch {
          // An error occurred while serializing the attachment. Encode it
          // separately for recovery on the calling side.
          let error = ABI.EncodedError<V>(encoding: error)
          try container.encode(error, forKey: .error)
        }
        if let errorWhileEncoding {
          throw errorWhileEncoding
        }
      }
    case let .inMemory(bytes):
      if V.includesExperimentalFields {
        try bytes.withUnsafeBytes(encodeBytes)
      }
    case let .error(error):
      if V.includesExperimentalFields {
        try container.encode(error, forKey: .error)
      }
    }
    if V.includesExperimentalFields {
      try container.encodeIfPresent(_preferredName, forKey: .preferredName)
    }
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    _kind = try {
      if let path = try container.decodeIfPresent(String.self, forKey: .path) {
        return .savedAtPath(path)
      }

      if V.includesExperimentalFields {
#if canImport(Foundation)
        // If possible, decode a whole Foundation Data object.
        if let data = try? container.decodeIfPresent(Data.self, forKey: .bytes) {
          return .inMemory([UInt8](data))
        }
#endif

        // Fall back to trying to decode an array of integers.
        if let bytes = try container.decodeIfPresent([UInt8].self, forKey: .bytes) {
          return .inMemory(bytes)
        }

        // Finally, look for an error caught during encoding.
        if let error = try container.decodeIfPresent(ABI.EncodedError<V>.self, forKey: .error) {
          return .error(error)
        }
      }

      // Couldn't find anything to decode.
      throw DecodingError.valueNotFound(
        String.self,
        DecodingError.Context(
          codingPath: decoder.codingPath + [CodingKeys.path],
          debugDescription: "Encoded attachment did not include any persistent representation."
        )
      )
    }()

    if V.includesExperimentalFields {
      _preferredName = try container.decodeIfPresent(String.self, forKey: .preferredName)
    }
  }
}

// MARK: - Attachable

extension ABI.EncodedAttachment: Attachable {
  public var estimatedAttachmentByteCount: Int? {
    switch _kind {
    case .savedAtPath, .error:
      return nil
    case let .inMemory(bytes):
      return bytes.count
    case let .abstract(attachment):
      return attachment.attachableValue.estimatedAttachmentByteCount
    }
  }

  /// An error type that is thrown when ``ABI/EncodedAttachment`` cannot satisfy
  /// a request for the underlying attachment's bytes.
  fileprivate struct BytesUnavailableError: Error {}

  public borrowing func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    switch _kind {
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
      return try bytes.withUnsafeBytes(body)
    case let .abstract(attachment):
      return try attachment.withUnsafeBytes(body)
    case let .error(error):
      throw error
    }
  }

  public borrowing func preferredName(for attachment: borrowing Attachment<Self>, basedOn suggestedName: String) -> String {
    _preferredName ?? suggestedName
  }
}

extension ABI.EncodedAttachment.BytesUnavailableError: CustomStringConvertible {
  var description: String {
    "The attachment's content could not be deserialized."
  }
}
