//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// An enumeration describing the encoding formats that you can use when
/// attaching a value that conforms to [`Encodable`](https://developer.apple.com/documentation/swift/encodable).
///
/// You can pass an instance of this type when you create an instance of
/// ``Testing/Attachment``. When the testing library saves your attachment, it
/// uses the value you pass to select an appropriate encoder and format.
///
/// If you want to attach a value that conforms to [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding),
/// use [`PropertyListFormat`](https://developer.apple.com/documentation/foundation/propertylistserialization/propertylistformat)
/// instead.
///
/// @Metadata {
///   @Available(Swift, introduced: 6.5)
/// }
public struct AttachableEncodingFormat: Sendable {
  /// An enumeration describing the various kinds of encoding format the testing
  /// library supports.
  package enum Kind: Sendable {
    /// A property list format.
    ///
    /// - Parameters:
    ///   - format: The corresponding property list format.
    ///
    /// Due to technical limitations, the associated value of this case is
    /// stored as a value of type `UInt` instead of `PropertyListFormat`.
    /// Callers are responsible for ensuring they only use values for `format`
    /// that Foundation recognizes.
    case propertyListFormat(_ format: UInt)

    /// The JSON format.
    case json
  }

  /// The kind of encoding format represented by this instance.
  package var kind: Kind

  package init(kind: Kind) {
    self.kind = kind
  }
}

/// @Metadata {
///   @Available(Swift, introduced: 6.5)
/// }
extension AttachableEncodingFormat: Equatable {}
extension AttachableEncodingFormat.Kind: Equatable {}
