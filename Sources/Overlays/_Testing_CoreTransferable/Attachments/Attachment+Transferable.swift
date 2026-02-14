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

public import UniformTypeIdentifiers

@_spi(Experimental)
@available(_transferableAPI, *)
extension Attachment {
  /// Initialize an instance of this type that encloses the given transferable
  /// value.
  ///
  /// - Parameters:
  ///   - transferableValue: The value that will be attached to the output of
  ///     the test run.
  ///   - contentType: The content type with which to export `transferableValue`.
  ///     If this argument is `nil`, the testing library calls [`exportedContentTypes(_:)`](https://developer.apple.com/documentation/coretransferable/transferable/exportedcontenttypes(_:))
  ///     on `transferableValue` and uses the first type the function returns
  ///     that conforms to [`UTType.data`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/data).
  ///   - preferredName: The preferred name of the attachment to use when saving
  ///     it. If `nil`, the testing library attempts to generate a reasonable
  ///     filename for the attached value.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// - Throws: Any error that occurs while exporting `transferableValue`.
  ///
  /// Use this initializer to create an instance of ``Attachment`` from a value
  /// that conforms to the [`Transferable`](https://developer.apple.com/documentation/coretransferable/transferable)
  /// protocol.
  ///
  /// ```swift
  /// let menu = FoodTruck.menu
  /// let attachment = try await Attachment(exporting: menu, as: .pdf)
  /// Attachment.record(attachment)
  /// ```
  ///
  /// When you call this initializer and pass it a transferable value, it
  /// calls [`exported(as:)`](https://developer.apple.com/documentation/coretransferable/transferable/exported(as:))
  /// on that value. This operation may take some time, so this initializer
  /// suspends the calling task until it is complete.
  public init<T>(
    exporting transferableValue: T,
    as contentType: UTType? = nil,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws where T: Transferable, AttachableValue == _AttachableTransferableWrapper<T> {
    let transferableWrapper = try await _AttachableTransferableWrapper(exporting: transferableValue, as: contentType)
    self.init(transferableWrapper, named: preferredName, sourceLocation: sourceLocation)
  }
}

// MARK: -

/// A type describing errors that can occur when attaching a transferable value.
enum TransferableAttachmentError: Error {
  /// The developer did not pass a content type and the value did not list any
  /// that conform to `UTType.data`.
  case suitableContentTypeNotFound
}

extension TransferableAttachmentError: CustomStringConvertible {
  var description: String {
    switch self {
    case .suitableContentTypeNotFound:
      "The value does not list any exported content types that conform to 'UTType.data'."
    }
  }
}
#endif
