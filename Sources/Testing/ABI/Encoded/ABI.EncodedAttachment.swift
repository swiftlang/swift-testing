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

#if canImport(Foundation)
private import Foundation
#endif

/// The maximum size, in bytes, of an attachment that will be stored inline in
/// an encoded attachment.
private let _maximumInlineAttachmentByteCount: Int = {
  let pageSize: Int
#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android)
  pageSize = Int(clamping: sysconf(_SC_PAGESIZE))
#elseif os(WASI)
  // sysconf(_SC_PAGESIZE) is a complex macro in wasi-libc.
  pageSize = Int(clamping: getpagesize())
#elseif os(Windows)
  var systemInfo = SYSTEM_INFO()
  GetSystemInfo(&systemInfo)
  pageSize = Int(clamping: systemInfo.dwPageSize)
#else
#warning("Platform-specific implementation missing: page size unknown (assuming 4KB)")
  pageSize = 4 * 1024
#endif

  return pageSize // i.e. we'll store up to a page-sized attachment
}()

extension ABI {
  /// A type implementing the JSON encoding of ``Attachment`` for the ABI entry
  /// point and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedAttachment<V>: Sendable where V: ABI.Version {
    /// The path where the attachment was written.
    var path: String?

    /// The preferred name of the attachment.
    ///
    /// - Warning: Attachments' preferred names are not yet part of the JSON
    ///   schema.
    var _preferredName: String?

    /// The raw content of the attachment, if available.
    ///
    /// If the value of this property is `nil`, the attachment can instead be
    /// read from ``path``.
    ///
    /// - Warning: Inline attachment content is not yet part of the JSON schema.
    var _bytes: Bytes?

    init(encoding attachment: borrowing Attachment<AnyAttachable>, in eventContext: borrowing Event.Context) {
      path = attachment.fileSystemPath
      _preferredName = attachment.preferredName

      if let estimatedByteCount = attachment.attachableValue.estimatedAttachmentByteCount,
         estimatedByteCount <= _maximumInlineAttachmentByteCount {
        _bytes = try? attachment.withUnsafeBytes { bytes in
          if bytes.count > 0 && bytes.count < _maximumInlineAttachmentByteCount {
            return Bytes(rawValue: [UInt8](bytes))
          }
          return nil
        }
      }
    }

    /// A structure representing the bytes of an attachment.
    struct Bytes: Sendable, RawRepresentable {
      var rawValue: [UInt8]
    }
  }
}

// MARK: - Codable

extension ABI.EncodedAttachment: Codable {}

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
    _bytes?.rawValue.count
  }

  fileprivate struct BytesUnavailableError: Error {}

  borrowing func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    if let bytes = _bytes?.rawValue {
      return try bytes.withUnsafeBytes(body)
    }

    guard let path else {
      throw BytesUnavailableError()
    }
    let fileHandle = try FileHandle(forReadingAtPath: path)
    // TODO: map the attachment back into memory
    let bytes = try fileHandle.readToEnd()
    return try bytes.withUnsafeBytes(body)
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
