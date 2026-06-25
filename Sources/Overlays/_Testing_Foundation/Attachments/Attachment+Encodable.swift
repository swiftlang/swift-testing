//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation) && !SWT_NO_CODABLE
public import Testing
public import Foundation
#if canImport(Combine)
public import Combine
#endif

@_spi(Experimental)
extension Attachment {
  /// Initialize an instance of this type representing a value that conforms to
  /// the [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
  /// protocol.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - encodingFormat: The encoding format to use to encode `encodableValue`.
  ///   - preferredName: The preferred name of the attachment when writing it to
  ///     a test report or to disk.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// Use this initializer to create an instance of ``Attachment`` from a value
  /// that conforms to the [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
  /// protocol:
  ///
  /// ```swift
  /// let menu = FoodTruck.currentMenu
  /// let attachment = try Attachment(encoding: menu, as: .json)
  /// Attachment.record(attachment)
  /// ```
  ///
  /// The encoding that the testing library uses depends on the `encodingFormat`
  /// argument. If the value of that argument is `nil`, the testing library uses
  /// the path extension specified in the `preferredName` argument instead.
  ///
  /// | Extension | Encoding Used | Encoder Used |
  /// |-|-|-|
  /// | `".xml"` | XML property list | [`PropertyListEncoder`](https://developer.apple.com/documentation/foundation/propertylistencoder) |
  /// | `".plist"` | Binary property list | [`PropertyListEncoder`](https://developer.apple.com/documentation/foundation/propertylistencoder) |
  /// | None, `".json"` | JSON | [`JSONEncoder`](https://developer.apple.com/documentation/foundation/jsonencoder) |
  ///
  /// - Important: OpenStep-style property lists are not supported.
  ///
  /// If the values of both the `encodingFormat` and `preferredName` arguments
  /// are `nil`, the testing library encodes `encodableValue` as JSON.
  public init<T>(
    encoding encodableValue: T,
    as encodingFormat: EncodingFormat? = nil,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where AttachableValue == _AttachableEncodableWrapper<T, Void> {
    let encodingFormat: EncodingFormat = if let encodingFormat {
      if case .propertyListFormat(.openStep) = encodingFormat {
        throw CocoaError(.propertyListWriteInvalid, userInfo: [NSLocalizedDescriptionKey: "The OpenStep property list format is not supported."])
      } else {
        encodingFormat
      }
    } else if let encodingFormat = try preferredName.flatMap(EncodingFormat.init(forPreferredName:)) {
      encodingFormat
    } else {
      // The developer did not specify, so default to JSON.
      .json
    }
    let wrapper = _AttachableEncodableWrapper(encoding: encodableValue, as: encodingFormat)
    self.init(wrapper, named: preferredName, sourceLocation: sourceLocation)
  }

#if canImport(Combine)
  /// Initialize an instance of this type representing a value that conforms to
  /// the [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
  /// protocol.
  ///
  /// - Parameters:
  ///   - encodableValue: The value to encode and attach.
  ///   - encoder: The encoder to use to encode `encodableValue`.
  ///   - preferredName: The preferred name of the attachment when writing it to
  ///     a test report or to disk.
  ///   - sourceLocation: The source location of the call to this initializer.
  ///     This value is used when recording issues associated with the
  ///     attachment.
  ///
  /// Use this initializer to create an instance of ``Attachment`` from a value
  /// that conforms to the [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
  /// protocol:
  ///
  /// ```swift
  /// let menu = FoodTruck.currentMenu
  /// let encoder = JSONEncoder()
  /// let attachment = try Attachment(encoding: menu, using: encoder)
  /// Attachment.record(attachment)
  /// ```
  public init<T, E>(
    encoding encodableValue: T,
    using encoder: E,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) where AttachableValue == _AttachableEncodableWrapper<T, E>, E: TopLevelEncoder, E.Output: ContiguousBytes {
    let wrapper = _AttachableEncodableWrapper(encoding: encodableValue, using: encoder)
    self.init(wrapper, named: preferredName, sourceLocation: sourceLocation)
  }
#endif
}
#endif
