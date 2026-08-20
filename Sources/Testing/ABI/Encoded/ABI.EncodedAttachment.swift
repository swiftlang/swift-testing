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
#if canImport(Foundation)
private import struct Foundation.Data
private import struct Foundation.URL
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
    fileprivate enum Kind: Sendable {
      /// The attachment has not been saved nor serialized yet and we still have
      /// it as an attachable value.
      case unserialized(Attachment<AnyAttachable>)

      /// The attachment was previously serialized and deserialized.
      ///
      /// - Precondition: At least one of `path` or `bytes` must not be `nil`.
      case serialized(path: String?, bytes: [UInt8]?)

      /// An error occurred when the attachment was encoded that prevented it
      /// from being properly serialized.
      case error(ABI.EncodedError<V>)
    }

    /// The kind of encoded attachment.
    fileprivate var kind: Kind

    /// The preferred name of the attachment.
    var preferredName: String?
  }
}

// MARK: - Codable

extension ABI.EncodedAttachment: Codable {
  private enum CodingKeys: String, CodingKey {
    case path
    case preferredName
    case bytes
    case error
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    func encodeBytes(_ bytes: UnsafeRawBufferPointer) throws {
#if canImport(Foundation)
      // If possible, encode this structure as Base64 data.
      let data = Data(bytesNoCopy: .init(mutating: bytes.baseAddress!), count: bytes.count, deallocator: .none)
      try container.encode(data.base64EncodedString(), forKey: .bytes)
#else
      // Otherwise, it's an array of integers.
      try container.encode(Array(bytes), forKey: .bytes)
#endif
    }

    switch kind {
    case let .serialized(path, bytes):
      if let path {
        try container.encode(path, forKey: .path)
      }
      if V.versionNumber >= ABI.v6_5.versionNumber, let bytes {
        try bytes.withUnsafeBytes(encodeBytes)
      }
    case let .unserialized(attachment):
      if let path = attachment.fileSystemPath {
        // If the attachment has already been saved to disk, don't bother trying
        // to serialize it a second time and just rely on the path. The
        // assumption here is that, if the caller passed --attachments-path,
        // they have access to that path and the files in it.
        try container.encode(path, forKey: .path)
      } else if V.versionNumber >= ABI.v6_5.versionNumber {
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
    case let .error(error):
      if V.versionNumber >= ABI.v6_5.versionNumber {
        try container.encode(error, forKey: .error)
      }
    }
    if V.versionNumber >= ABI.v6_5.versionNumber {
      try container.encodeIfPresent(preferredName, forKey: .preferredName)
    }
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    kind = try {
      let path = try container.decodeIfPresent(String.self, forKey: .path)

      var bytes: [UInt8]?
      if V.versionNumber >= ABI.v6_5.versionNumber {
#if canImport(Foundation)
        // If possible, decode a whole Foundation Data object.
        if bytes == nil,
           let data = try? container.decodeIfPresent(Data.self, forKey: .bytes) {
          bytes = [UInt8](data)
        }
#endif

        // Fall back to trying to decode an array of integers.
        if bytes == nil {
          bytes = try container.decodeIfPresent([UInt8].self, forKey: .bytes)
        }
      }

      // Finally, look for an error caught during encoding.
      if path == nil && bytes == nil,
         V.versionNumber >= ABI.v6_5.versionNumber,
         let error = try container.decodeIfPresent(ABI.EncodedError<V>.self, forKey: .error) {
        return .error(error)
      }

      return .serialized(path: path, bytes: bytes)
    }()

    if V.versionNumber >= ABI.v6_5.versionNumber {
      preferredName = try container.decodeIfPresent(String.self, forKey: .preferredName)
    }
  }
}

// MARK: - Attachable

extension ABI.EncodedAttachment: Attachable {
  public var estimatedAttachmentByteCount: Int? {
    switch kind {
    case .error:
      return nil
    case let .serialized(_, bytes):
      return bytes?.count
    case let .unserialized(attachment):
      return attachment.attachableValue.estimatedAttachmentByteCount
    }
  }

  /// An error type that is thrown when ``ABI/EncodedAttachment`` cannot satisfy
  /// a request for the underlying attachment's bytes.
  fileprivate struct BytesUnavailableError: Error {}

  public borrowing func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    switch kind {
    case let .serialized(path, bytes):
      if let bytes {
        return try bytes.withUnsafeBytes(body)
      }

#if !SWT_NO_FILE_IO
      if let path {
#if canImport(Foundation)
        // Leverage Foundation's file-mapping logic since we're using Data anyway.
        let url = URL(fileURLWithPath: path, isDirectory: false)
        let bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
#else
        let fileHandle = try FileHandle(forReadingAtPath: path)
        let bytes = try fileHandle.readToEnd()
#endif
        return try bytes.withUnsafeBytes(body)
      }
#endif

      // Cannot read the attachment from disk on this platform, or the decoded
      // attachment contained neither "path" nor "bytes".
      throw BytesUnavailableError()

    case let .unserialized(attachment):
      return try attachment.withUnsafeBytes(body)
    case let .error(error):
      throw error
    }
  }

  public borrowing func preferredName(for attachment: borrowing Attachment<Self>, basedOn suggestedName: String) -> String {
    preferredName ?? suggestedName
  }
}

#if !SWT_NO_FILE_CLONING
extension ABI.EncodedAttachment: FileClonable {
  package func clone(toFileAtPath filePath: String) -> Bool {
    guard case let .unserialized(attachment) = kind else {
      return false
    }
    return attachment.attachableValue.clone(toFileAtPath: filePath)
  }
  
}
#endif

extension ABI.EncodedAttachment.BytesUnavailableError: CustomStringConvertible {
  var description: String {
    "The attachment's content could not be deserialized."
  }
}

// MARK: - Conversion to/from library types

extension ABI.EncodedAttachment {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - attachment: The attachment to initialize this instance from.
  public init(encoding attachment: borrowing Attachment<AnyAttachable>) {
    kind = .unserialized(copy attachment)
    preferredName = attachment.preferredName
  }

  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - attachment: The attachment to initialize this instance from.
  public init(encoding attachment: borrowing Attachment<some Attachable & Sendable & ~Copyable>) {
    let attachmentCopy = Attachment<AnyAttachable>(copy attachment)
    self.init(encoding: attachmentCopy)
  }
}

@_spi(ForToolsIntegrationOnly)
extension Attachment where AttachableValue == AnyAttachable {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - event: The encoded event to initialize this instance from.
  ///
  /// If `event` does not represent an attached value, the initializer returns
  /// `nil`.
  public init?<V>(decoding event: ABI.EncodedEvent<V>) {
    guard let attachment = event.attachment else {
      return nil
    }
    self.init(decoding: attachment)
    if let sourceLocation = event.sourceLocation.flatMap(SourceLocation.init(decoding:)) {
      self.sourceLocation = sourceLocation
    }
  }

  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - attachment: The encoded attachment to initialize this instance from.
  public init?<V>(decoding attachment: ABI.EncodedAttachment<V>) {
    switch attachment.kind {
    case let .unserialized(attachment):
      self = attachment // No need to nest it further.
    default:
      var attachmentCopy = Attachment<ABI.EncodedAttachment<V>>(attachment, sourceLocation: .unknown)
      if case let .serialized(path, _) = attachment.kind {
        attachmentCopy.fileSystemPath = path
      }
      self.init(attachmentCopy)
    }
  }
}
#endif
