//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

#if canImport(Synchronization)
private import Synchronization
#endif

extension ABI {
  /// A type describing an ABI version number.
  ///
  /// This type implements a subset of the [semantic versioning](https://semver.org)
  /// specification (specifically parsing, displaying, and comparing
  /// `<version core>` values we expect that the testing library will need for
  /// the foreseeable future.)
  ///
  /// You can use this type and its conformance to [`Codable`](https://developer.apple.com/documentation/swift/codable),
  /// when integrating the testing library with development tools. It is not
  /// part of the testing library's public interface.
  public struct VersionNumber: Sendable {
    /// The integer type used to store a component.
    ///
    /// The testing library does not generally need to deal with version numbers
    /// whose components exceed the width of this type. If we need to deal with
    /// larger version number components in the future, we can increase the width
    /// of this type accordingly.
    typealias Component = Int8

    /// The major version.
    var majorComponent: Component

    /// The minor version.
    var minorComponent: Component

    /// The patch, revision, or bug fix version.
    var patchComponent: Component = 0
  }
}

extension ABI.VersionNumber {
  init(_ majorComponent: _const Component, _ minorComponent: _const Component, _ patchComponent: _const Component = 0) {
    self.init(majorComponent: majorComponent, minorComponent: minorComponent, patchComponent: patchComponent)
  }
}

// MARK: - CustomStringConvertible

extension ABI.VersionNumber: CustomStringConvertible {
  /// A cache of previously-parsed version numbers.
  private static let _versionNumberCache = Mutex<[String: Self?]>()

  /// Parse an instance of this type from the given string.
  ///
  /// - Parameters:
  ///   - string: The string to parse, such as `"0"` or `"6.3.0"`.
  ///
  /// - Returns: An instance of this type, or `nil` if one could not be parsed
  ///   from `string`.
  ///
  /// - Bug: We are not able to reuse the logic from swift-syntax's
  ///   `VersionTupleSyntax` type here because we cannot link to swift-syntax
  ///   in this target.
  private static func _parse(_ string: String) -> Self? {
    // Check if we've previously encountered this version number.
    let cachedValue = Self._versionNumberCache.withLock { versionNumberCache in
      versionNumberCache[string]
    }
    if case let .some(cachedValue) = cachedValue {
      return cachedValue
    }

    var result: Self?
    do {
      // Split the string on "." (assuming it is of the form "1", "1.2", or
      // "1.2.3") and parse the individual components as integers.
      let components = string.split(separator: ".", omittingEmptySubsequences: false)
      func componentValue(_ index: Int) -> Component? {
        components.count > index ? Component(components[index]) : 0
      }
      if let majorComponent = componentValue(0),
         let minorComponent = componentValue(1),
         let patchComponent = componentValue(2) {
        result = Self(majorComponent: majorComponent, minorComponent: minorComponent, patchComponent: patchComponent)
      }
    }

    Self._versionNumberCache.withLock { versionNumberCache in
      versionNumberCache[string] = result
    }

    return result
  }

  /// Initialize an instance of this type by parsing the given string.
  ///
  /// - Parameters:
  ///   - string: The string to parse, such as `"0"` or `"6.3.0"`.
  ///
  /// If `string` contains fewer than 3 numeric components, the missing
  /// components are inferred to be `0` (for example, `"1.2"` is equivalent to
  /// `"1.2.0"`.) If `string` contains more than 3 numeric components, the
  /// additional components are ignored.
  public init?(_ string: String) {
    guard let result = Self._parse(string) else {
      return nil
    }
    self = result
  }

  /// Initialize an instance of this type by parsing the given string.
  ///
  /// - Parameters:
  ///   - string: The C string to parse, such as `"0"` or `"6.3.0"`.
  ///
  /// @Comment {
  ///   - Bug: We are not able to reuse the logic from swift-syntax's
  ///     `VersionTupleSyntax` type here because we cannot link to swift-syntax
  ///     in this target.
  /// }
  ///
  /// If `string` contains fewer than 3 numeric components, the missing
  /// components are inferred to be `0` (for example, `"1.2"` is equivalent to
  /// `"1.2.0"`.) If `string` contains more than 3 numeric components, the
  /// additional components are ignored.
  public init?(validatingCString string: UnsafePointer<CChar>) {
    guard let result = String(validatingCString: string).flatMap(Self._parse) else {
      return nil
    }
    self = result
  }

  public var description: String {
    if majorComponent <= 0 && minorComponent == 0 && patchComponent == 0 {
      // Version 0 and earlier are described as integers for compatibility with
      // Swift 6.2 and earlier.
      return String(describing: majorComponent)
    } else if patchComponent == 0 {
      return "\(majorComponent).\(minorComponent)"
    }
    return "\(majorComponent).\(minorComponent).\(patchComponent)"
  }
}

// MARK: - Equatable, Comparable

extension ABI.VersionNumber: Equatable, Comparable {
  public static func <(lhs: Self, rhs: Self) -> Bool {
    if lhs.majorComponent != rhs.majorComponent {
      return lhs.majorComponent < rhs.majorComponent
    } else if lhs.minorComponent != rhs.minorComponent {
      return lhs.minorComponent < rhs.minorComponent
    } else if lhs.patchComponent != rhs.patchComponent {
      return lhs.patchComponent < rhs.patchComponent
    }
    return false
  }
}

#if !SWT_NO_CODABLE
// MARK: - Codable

extension ABI.VersionNumber: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let number = try? container.decode(Component.self) {
      // Allow for version numbers encoded as integers for compatibility with
      // Swift 6.2 and earlier.
      self.init(majorComponent: number, minorComponent: 0)
    } else {
      let string = try container.decode(String.self)
      guard let result = Self(string) else {
        throw DecodingError.dataCorrupted(
          .init(
            codingPath: decoder.codingPath,
            debugDescription: "Unexpected string '\(string)' (expected an integer or a string of the form '1.2.3')"
          )
        )
      }
      self = result
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    if majorComponent <= 0 && minorComponent == 0 && patchComponent == 0 {
      // Version 0 and earlier are encoded as integers for compatibility with
      // Swift 6.2 and earlier.
      try container.encode(majorComponent)
    } else {
      try container.encode("\(majorComponent).\(minorComponent).\(patchComponent)")
    }
  }

#if !SWT_NO_ABI_JSON_SCHEMA
  /// Initialize an instance of this type from the ABI version number encoded in
  /// a record's JSON representation without decoding the entire record.
  ///
  /// - Parameters:
  ///   - recordJSON: The record JSON to partially decode.
  ///
  /// - Throws: Any error that prevented decoding an instance of this type.
  public init(fromRecordJSON recordJSON: UnsafeRawBufferPointer) throws {
#if !os(Windows) // no memmem()
    // This is sneaky: if we find the substring ""version": " in the JSON, and
    // we only find it once, we can assume that what follows up to a comma,
    // whitespace, or brace must be the record's version. This is not a safe or
    // general way to parse JSON of course, so if it fails we fall back to full
    // JSON decoding.
    //
    // "What happens if we extract the string from the wrong place?" Then the
    // caller will proceed to decode the entire record with an incorrect
    // ABI.VersionNumber and/or ABI.Version specialization, and decoding will
    // throw an error (as it would have if we just used `JSON.decode()` below).
    //
    if #available(_stringInitValidatingAPI, *) {
      let versionKey = (
        UInt8(ascii: #"""#), UInt8(ascii: "v"), UInt8(ascii: "e"), UInt8(ascii: "r"),
        UInt8(ascii: "s"), UInt8(ascii: "i"), UInt8(ascii: "o"), UInt8(ascii: "n"),
        UInt8(ascii: #"""#), UInt8(ascii: ":"), UInt8(ascii: " ")
      )
      let result: Self? = withUnsafeBytes(of: versionKey) { versionKey in
        // NOTE: firstRange(of:) is very slow in DEBUG configuration because it
        // is completely unspecialized, so drop to memmem() to find the range.
        func find(_ needle: UnsafeRawBufferPointer, in haystack: UnsafeRawBufferPointer) -> Range<UnsafeRawBufferPointer.Index>? {
          guard let address = memmem(haystack.baseAddress!, haystack.count, needle.baseAddress!, needle.count) else {
            return nil
          }
          let offset = UnsafeRawPointer(address) - haystack.baseAddress!
          let startIndex = haystack.index(haystack.startIndex, offsetBy: offset)
          let endIndex = haystack.index(startIndex, offsetBy: needle.count)
          return startIndex ..< endIndex
        }

        // Find the "version" key.
        guard let range = find(versionKey, in: recordJSON),
              range.upperBound < recordJSON.endIndex else {
          return nil
        }
        var slicedJSON = UnsafeRawBufferPointer(rebasing: recordJSON[range.endIndex...])
        guard find(versionKey, in: slicedJSON) == nil else {
          // The key was present twice, so this JSON is likely invalid.
          return nil
        }

        if slicedJSON.first == UInt8(ascii: #"""#) {
          // Appears to be a string. Find the next quote character; as long as
          // there are no escape sequences, we can extract the string directly.
          slicedJSON = UnsafeRawBufferPointer(rebasing: slicedJSON.dropFirst())
          return withUnsafeBytes(of: UInt8(ascii: #"""#)) { quote in
            guard let endQuoteRange = find(quote, in: slicedJSON) else {
              return nil
            }
            slicedJSON = UnsafeRawBufferPointer(rebasing: slicedJSON[..<endQuoteRange.startIndex])
            return withUnsafeBytes(of: UInt8(ascii: #"\"#)) { backslash in
              guard find(backslash, in: slicedJSON) == nil,
                    let stringValue = String(validating: slicedJSON, as: UTF8.self) else {
                return nil
              }
              return Self(stringValue)
            }
          }
        }

        return nil
      }
      if let result {
        self = result
        return
      }
    }
#endif

    struct MinimalRecord: Decodable {
      var version: ABI.VersionNumber
    }
    self = try JSON.decode(MinimalRecord.self, from: recordJSON).version
  }
#endif
}
#endif
