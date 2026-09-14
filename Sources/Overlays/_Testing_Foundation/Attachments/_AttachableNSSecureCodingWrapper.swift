//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_FOUNDATION && !SWT_NO_CODABLE
public import Testing
public import Foundation

/// A wrapper type representing values that can be attached using their
/// conformances to the `NSSecureCoding` protocol.
///
/// You do not need to use this type directly. Instead, initialize an instance
/// of ``Attachment`` using the encodable value.
public struct _AttachableNSSecureCodingWrapper<T> where T: NSSecureCoding {
  /// The underlying encodable value.
  private var _encodableValue: T

  /// The encoding format used when encoding the value.
  private var _propertyListFormat: PropertyListSerialization.PropertyListFormat

  /// Initialize an instance of this type representing a given encodable value
  /// and encoding it using the given encoding format.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - propertyListFormat: The property list format to use.
  init(encoding encodableValue: T, as propertyListFormat: PropertyListSerialization.PropertyListFormat) {
    _encodableValue = encodableValue
    _propertyListFormat = propertyListFormat
  }
}

extension _AttachableNSSecureCodingWrapper: Sendable where T: Sendable {}

// MARK: -

extension _AttachableNSSecureCodingWrapper: AttachableWrapper {
  public var wrappedValue: T {
    _encodableValue
  }

  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<_AttachableNSSecureCodingWrapper>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var data = try NSKeyedArchiver.archivedData(withRootObject: _encodableValue, requiringSecureCoding: true)

    // BUG: Foundation does not offer a variant of
    // NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding:)
    // that is Swift-safe (throws errors instead of exceptions) and lets the
    // caller specify the output format. Work around this issue by decoding
    // the archive re-encoding it manually.
    if _propertyListFormat != .binary {
      let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
      data = try PropertyListSerialization.data(fromPropertyList: plist, format: _propertyListFormat, options: 0)
    }

    return try data.withUnsafeBytes(body)
  }

  public borrowing func preferredName(for attachment: borrowing Attachment<_AttachableNSSecureCodingWrapper>, basedOn suggestedName: String) -> String {
    let encodingFormat = AttachableEncodingFormat.propertyListFormat(_propertyListFormat)
    return encodingFormat.preferredName(basedOn: suggestedName)
  }
}
#endif
