//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && !hasFeature(Embedded) && canImport(UniformTypeIdentifiers)
@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
import UniformTypeIdentifiers
@_spi(Experimental) import _Testing_UniformTypeIdentifiers

struct `Attachment.preferredContentType tests` {
  @Test func `Can resolve a content type from an attachable value`() {
    let attachableValue = AttachableValueWithContentType(contentType: .mp3)
    let attachment = Attachment(attachableValue)
    #expect(attachment.preferredContentType == .mp3)
  }

  @Test func `ABI.EncodedAttachment preserves content type`() throws {
    let contentType = try #require(UTType(filenameExtension: "nonexistent-type-one-hopes"))
    #expect(contentType.isDynamic)
    let attachableValue = AttachableValueWithContentType(contentType: contentType)
    let attachment = Attachment(attachableValue)
    #expect(attachment.preferredContentType == contentType)

    // Roundtrip through ABI.EncodedAttachment
    let encodedAttachment = ABI.EncodedAttachment<ABI.ExperimentalVersion>(encoding: attachment)
    let attachmentCopy = try #require(Attachment(decoding: encodedAttachment))
    #expect(attachmentCopy.preferredContentType == contentType)

    // Roundtrip through JSON.
    let encodedAttachmentCopy = try JSON.encodeAndDecode(encodedAttachment)
    let attachmentCopy2 = try #require(Attachment(decoding: encodedAttachmentCopy))
    #expect(attachmentCopy2.preferredContentType == contentType)
  }
}

// MARK: - Fixtures

fileprivate struct AttachableValueWithContentType: Attachable {
  var contentType: UTType

  func withUnsafeBytes<R>(for attachment: borrowing Testing.Attachment<AttachableValueWithContentType>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    throw MyDescriptiveError(description: "Unimplemented")
  }
  
  func _preferredContentType(for attachment: borrowing Attachment<Self>) -> UTType? {
    contentType
  }
}
#endif
