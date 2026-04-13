//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing a test content record's `kind` field.
///
/// Test content kinds are 32-bit unsigned integers and are stored as such when
/// test content records are emitted at compile time.
///
/// This type lets you represent a kind value as an integer literal or as a
/// string literal in Swift code. In particular, when adding a conformance to
/// the ``DiscoverableAsTestContent`` protocol, the protocol's
/// ``DiscoverableAsTestContent/testContentKind`` property must be an instance
/// of this type.
///
/// For a list of reserved values, or to reserve a value for your own use, see
/// `ABI/TestContent.md`.
///
/// @Comment {
///   This type is `@frozen` and most of its members are `@inlinable` because it
///   represents the underlying `kind` field which has a fixed layout. In the
///   future, we may want to use this type in test content records, but that
///   will require the type be publicly visible and that `@const` is implemented
///   in the compiler.
/// }
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
@frozen public struct TestContentKind: Sendable, BitwiseCopyable, RawRepresentable {
  public var rawValue: UInt32

  @inlinable public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }
}

// MARK: - Equatable, Hashable

extension TestContentKind: Equatable, Hashable {
  @inlinable public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue == rhs.rawValue
  }

  @inlinable public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue)
  }
}

#if !hasFeature(Embedded)
// MARK: - Codable

extension TestContentKind: Codable {}
#endif

// MARK: - ExpressibleByStringLiteral, ExpressibleByIntegerLiteral

extension TestContentKind: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
  @inlinable public init(stringLiteral stringValue: StaticString) {
    let rawValue = stringValue.withUTF8Buffer { stringValue in
      precondition(stringValue.count == MemoryLayout<UInt32>.stride, #""\#(stringValue)".utf8CodeUnitCount = \#(stringValue.count), expected \#(MemoryLayout<UInt32>.stride)"#)
      let bigEndian = UnsafeRawBufferPointer(stringValue).loadUnaligned(as: UInt32.self)
      return UInt32(bigEndian: bigEndian)
    }
    self.init(rawValue: rawValue)
  }

  @inlinable public init(integerLiteral: UInt32) {
    self.init(rawValue: integerLiteral)
  }
}

// MARK: - CustomStringConvertible

extension TestContentKind: CustomStringConvertible {
  /// This test content type's kind value as an ASCII string (of the form
  /// `"abcd"`) if it looks like it might be a [FourCC](https://en.wikipedia.org/wiki/FourCC)
  /// value, or `nil` if not.
  package var fourCharacterCodeValue: String? {
    withUnsafeBytes(of: rawValue.bigEndian) { bytes in
      // All printable ASCII characters are in the range 0x20 ..< 0x7F.
      func isPrintableASCII(_ byte: UInt8) -> Bool {
        Unicode.ASCII.isASCII(byte) && byte >= 0x20 && byte < 0x7F
      }

      guard bytes.allSatisfy(isPrintableASCII) else {
        return nil
      }
      return String(decoding: bytes, as: Unicode.ASCII.self)
    }
  }

  public var description: String {
    let hexValue = "0x" + String(rawValue, radix: 16)
    if let fourCharacterCodeValue {
      return "'\(fourCharacterCodeValue)' (\(hexValue))"
    }
    return hexValue
  }
}

// MARK: - Constants

// NOTE: The set of constants in this extension should be a subset of the
// constants specified in Documentation/ABI/TestContent.md.

extension TestContentKind {
  /// A test or suite declaration.
  package static var testDeclaration: Self { "test" }

  /// An exit test.
  package static var exitTest: Self { "exit" }

  /// A Swift playground.
  package static var playground: Self { "play" }
}
