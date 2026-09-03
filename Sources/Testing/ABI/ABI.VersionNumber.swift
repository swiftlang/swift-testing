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

    /// A type describing flags for version numbers.
    ///
    /// When converting a version number to or from a string, all flags are
    /// represented as "pre-release identifiers" per the semantic versioning
    /// specification.
    ///
    /// - Important: The semantic versioning specification requires that the
    ///   order of prerelease IDs be preserved so that it can factor into
    ///   version number comparisons. This type does _not_ follow that rule so
    ///   we can save space: if we preserved ordering, the stride of
    ///   ``ABI/VersionNumber`` would need to be at least as large as two
    ///   pointers to hold the numeric components, the flags, and their
    ///   ordering.
    struct Flags: OptionSet {
      var rawValue: Component.Magnitude

      /// The owning version number represents a development build of the
      /// testing library.
      static var developmentBuild: Self { .init(rawValue: 1 << 0) }

      /// Whether or not the testing library was built as a debug build.
      ///
      /// - Note: We only ever use this flag in our own debug builds to allow
      ///   for testing the logic in this file.
      static var debugBuild: Self { .init(rawValue: 1 << (RawValue.bitWidth - 1)) }
    }

    /// Flags for this instance.
    var flags: Flags = []
  }
}

extension ABI.VersionNumber {
  init(_ majorComponent: _const Component, _ minorComponent: _const Component, _ patchComponent: _const Component = 0, flags: Flags = []) {
    self.init(majorComponent: majorComponent, minorComponent: minorComponent, patchComponent: patchComponent, flags: flags)
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
    // The empty string is obviously invalid.
    if string.isEmpty {
      return nil
    }

    // Check if we've previously encountered this version number.
    let cachedValue = Self._versionNumberCache.withLock { versionNumberCache in
      versionNumberCache[string]
    }
    if case let .some(cachedValue) = cachedValue {
      return cachedValue
    }

    var result: Self?
    do {
      // Split the string on "-" once to extract any prerelease identifiers. We
      // need to continue to support a negative major component, so if the first
      // character is "-", we need to skip it during splitting, then insert it
      // back into the first string.
      var componentsThenPrereleaseIDs: [Substring]
      if string.first == "-" {
        componentsThenPrereleaseIDs = string.dropFirst().split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let allComponents = componentsThenPrereleaseIDs[0]
        componentsThenPrereleaseIDs[0] = string[..<allComponents.endIndex]
      } else {
        componentsThenPrereleaseIDs = string.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
      }

      // Split the string on "." (assuming it is of the form "1", "1.2", or
      // "1.2.3") and parse the individual components as integers.
      let allComponents = componentsThenPrereleaseIDs[0]
      let components = allComponents.split(separator: ".", omittingEmptySubsequences: false)
      func componentValue(_ index: Int) -> Component? {
        components.count > index ? Component(components[index]) : 0
      }
      if let majorComponent = componentValue(0),
         let minorComponent = componentValue(1),
         let patchComponent = componentValue(2) {
        result = Self(majorComponent: majorComponent, minorComponent: minorComponent, patchComponent: patchComponent)
      }

      if componentsThenPrereleaseIDs.count > 1 {
        let allPrereleaseIDs = componentsThenPrereleaseIDs[1]
        if allPrereleaseIDs.isEmpty {
          // There was a trailing "-" which is invalid.
          result = nil
        } else {
          let prereleaseIDs = allPrereleaseIDs.split(separator: ".", omittingEmptySubsequences: false)

          var flags: Flags = []
          for prereleaseID in prereleaseIDs {
            guard let flag = Flags(prereleaseID: prereleaseID) else {
              result = nil
              break
            }
            flags.insert(flag)
          }
          result?.flags = flags
        }
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
    if majorComponent <= 0 && minorComponent == 0 && patchComponent == 0 && flags.isEmpty {
      // Version 0 and earlier are described as integers for compatibility with
      // Swift 6.2 and earlier.
      return String(describing: majorComponent)
    } else if patchComponent == 0 {
      return "\(majorComponent).\(minorComponent)\(flags.prereleaseIDSuffix)"
    }
    return "\(majorComponent).\(minorComponent).\(patchComponent)\(flags.prereleaseIDSuffix)"
  }
}

// MARK: - Equatable, Comparable, Hashable

extension ABI.VersionNumber: Equatable, Comparable {
  public static func <(lhs: Self, rhs: Self) -> Bool {
    if lhs.majorComponent != rhs.majorComponent {
      return lhs.majorComponent < rhs.majorComponent
    } else if lhs.minorComponent != rhs.minorComponent {
      return lhs.minorComponent < rhs.minorComponent
    } else if lhs.patchComponent != rhs.patchComponent {
      return lhs.patchComponent < rhs.patchComponent
    } else if case let lhs = lhs.flags.rawValue.nonzeroBitCount,
              case let rhs = rhs.flags.rawValue.nonzeroBitCount,
              lhs != rhs {
      if lhs == 0 {
        return false
      } else if rhs == 0 {
        return true
      }
      return lhs < rhs
    } else if lhs.flags != rhs.flags {
      for (lhs, rhs) in zip(lhs.flags.prereleaseIDs, rhs.flags.prereleaseIDs) {
        if lhs != rhs {
          return lhs < rhs
        }
      }
    }
    return false
  }
}

extension ABI.VersionNumber.Flags: Equatable, Hashable {}

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
    if majorComponent <= 0 && minorComponent == 0 && patchComponent == 0 && flags.isEmpty {
      // Version 0 and earlier are encoded as integers for compatibility with
      // Swift 6.2 and earlier.
      try container.encode(majorComponent)
    } else {
      try container.encode("\(majorComponent).\(minorComponent).\(patchComponent)\(flags.prereleaseIDSuffix)")
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
    struct MinimalRecord: Decodable {
      var version: ABI.VersionNumber
    }
    self = try JSON.decode(MinimalRecord.self, from: recordJSON).version
  }
#endif
}

// MARK: - Converting flags to/from semver prerelease IDs

extension ABI.VersionNumber.Flags {
  /// The set of recognized prerelease IDs keyed by their corresponding ``Flag``
  /// values.
  private static let _prereleaseIDsByFlag: [Self: String] = [
    .developmentBuild: "dev",
    .debugBuild: "debug",
  ]

  /// The set of recognized ``Flag`` values keyed by their corresponding
  /// prerelease IDs.
  ///
  /// The keys of this dictionary are substrings to allow lookup during parsing
  /// without needing to copy substrings of the original string.
  private static let _flagsByPrereleaseID = Dictionary(
    uniqueKeysWithValues: _prereleaseIDsByFlag.map { ($1[...], $0) }
  )

  /// The set of non-zero bits set in this instance's raw value.
  ///
  /// The order of the values in this sequence is from low bit to high bit.
  ///
  /// Bits are represented here as masks, not positionally. For example, the
  /// bit `0b10` is represented here as `(1 << 1)`, not as `1`.
  fileprivate var nonZeroBits: some Sequence<RawValue> {
    sequence(state: rawValue) { rawValue in
      if rawValue.nonzeroBitCount == 0 {
        return nil
      }
      let lowBit = RawValue(1 << rawValue.trailingZeroBitCount)
      rawValue &= ~lowBit
      return lowBit
    }
  }

  /// The set of prerelease IDs, per the semantic versioning specification,
  /// represented by this instance.
  ///
  /// The order of strings in this sequence matches that of ``nonZeroBits``.
  var prereleaseIDs: some Sequence<String> {
    nonZeroBits.lazy
      .map(Self.init(rawValue:))
      .compactMap { Self._prereleaseIDsByFlag[$0] }
  }

  /// The suffix to apply to the owning instance of ``ABI/VersionNumber``
  /// when converting it to a string.
  fileprivate var prereleaseIDSuffix: String {
    if self.isEmpty {
      return ""
    }
    return "-" + prereleaseIDs.joined(separator: ".")
  }

  init?<S>(prereleaseID: S) where S: StringProtocol, S.SubSequence == Substring {
    guard let flag = Self._flagsByPrereleaseID[prereleaseID[...]] else {
      return nil
    }

    self = flag
  }
}
#endif
