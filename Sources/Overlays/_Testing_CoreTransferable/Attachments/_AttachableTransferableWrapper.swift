//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(CoreTransferable)
public import Testing
public import CoreTransferable

private import Foundation
import UniformTypeIdentifiers

/// A wrapper type representing transferable values that can be attached
/// indirectly.
///
/// You do not need to use this type directly. Instead, initialize an instance
/// of ``Attachment`` using an instance of a type conforming to the [`Transferable`](https://developer.apple.com/documentation/coretransferable/transferable)
/// protocol.
@_spi(Experimental)
@available(_transferableAPI, *)
public struct _AttachableTransferableWrapper<T>: Sendable where T: Transferable {
  /// The transferable value.
  private var _transferableValue: T

  /// The content type used to export the transferable value.
  private var _contentType: UTType

  /// The exported form of the transferable value.
  private var _bytes: Data

  init(exporting transferableValue: T, as contentType: UTType?) async throws {
    let contentType = contentType ?? transferableValue.exportedContentTypes()
      .first { $0.conforms(to: .data) }
    guard let contentType else {
      throw TransferableAttachmentError.suitableContentTypeNotFound
    }

    _transferableValue = transferableValue
    _contentType = contentType
    _bytes = try await transferableValue.exported(as: contentType)
  }
}

// MARK: -

@_spi(Experimental)
@available(_transferableAPI, *)
extension _AttachableTransferableWrapper: AttachableWrapper {
  public var wrappedValue: T {
    _transferableValue
  }

  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try _bytes.withUnsafeBytes(body)
  }

  public borrowing func preferredName(for attachment: borrowing Attachment<Self>, basedOn suggestedName: String) -> String {
    let baseName = _transferableValue.suggestedFilename ?? suggestedName
    return (baseName as NSString).appendingPathExtension(for: _contentType)
  }
}
#endif
