//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && !hasFeature(Embedded) && canImport(UniformTypeIdentifiers)
public import Testing
public import UniformTypeIdentifiers

private import Foundation

extension UTType: UTTypeConvertible {}

extension Attachment {
  /// Derive a content type for this attachment from its ``preferredName``
  /// property.
  ///
  /// - Returns: An instance of `UTType` derived from ``preferredName``, or
  ///   `nil` if none could be derived.
  private func _deriveContentTypeFromPreferredName() -> UTType? {
    let pathExtension = (preferredName as NSString).pathExtension
    guard !pathExtension.isEmpty,
          let result = UTType(filenameExtension: pathExtension),
          !result.isDynamic else {
      return nil
    }
    return result
  }

  /// Get a content type for this attachment from its attachable value's
  /// `_preferredContentType(for:)` function.
  ///
  /// - Returns: An instance of `UTType` derived from the attachable value's
  ///   `_preferredContentType(for:)` function, or `nil` if none was specified
  ///   or if the specified content type was not valid.
  private func _contentTypeFromAttachableRequirement() -> UTType? {
    guard let result = attachableValue._preferredContentType(for: self) else {
      // The attachable value did not specify a content type at all.
      return nil
    }
    if let result = result as? UTType {
      // Fast path to avoid a Launch Services lookup if we already have a UTType
      // instance that's been type-erased.
      return result
    } else if let result = result as? UTTypeProxy, let wrappedType = result.wrappedType as? UTType {
      // The value provided by the attachable value is a UTTypeProxy that wraps
      // a UTType instance. We can once again avoid a Launch Services lookup.
      return wrappedType
    } else if let result = result as? any UTTypeConvertible {
      // Ask Launch Services to give us the UTType instance for the available
      // type identifier. Launch Services may return `nil` at this point.
      return UTType(result.identifier)
    }

    return nil
  }

  /// The preferred content type to use when saving this attachment, if any.
  ///
  /// If the attachment's underlying value specifies a preferred content type
  /// that conforms to [`UTType.data`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/data),
  /// the value of this property is equal to that content type. Otherwise, the
  /// testing library attempts to derive a value from the attachment's
  /// ``preferredName`` property instead.
  @_spi(Experimental)
  public var preferredContentType: UTType? {
    var result = _contentTypeFromAttachableRequirement()

    if result == nil {
      // The attachable value did not specify a content type, or we couldn't
      // convert it to a valid instance of UTType, so try to derive one from the
      // attachment's preferred name instead.
      result = _deriveContentTypeFromPreferredName()
    }

    if let result, result.conforms(to: .data) {
      return result
    }
    return nil
  }
}
#endif
