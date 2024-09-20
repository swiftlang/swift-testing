//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type providing unique identifiers for expressions captured during
/// expansion of the `#expect()` and `#require()` macros.
///
/// - Warning: This type is used to implement the `#expect()` and `#require()`
///   macros. Do not use it directly.
public struct __ExpressionID: Sendable {
  /// The string produced at compile time that encodes the unique identifier of
  /// the represented expression.
  var stringValue: String

  /// The number of bits in a nybble.
  private static var _bitsPerNybble: Int { 4 }

  /// The ID of the syntax node represented by this instance.
  var nodeID: UInt32 {
    // The ID is encoded as the highest non-zero bit in the string, so that's
    // nybbles.first.highestBit + ((nybbles.count - 1) * bitsPerNybble)
    if stringValue.isEmpty {
      return 0
    }

    let stringNybble = stringValue[stringValue.startIndex ... stringValue.startIndex]
    guard let nybble = UInt8(stringNybble, radix: 16) else {
      return 0
    }

    let highestBit = UInt8.bitWidth - nybble.leadingZeroBitCount
    return UInt32(highestBit) + UInt32((stringValue.count - 1) * Self._bitsPerNybble)
  }

  /// A representation of this instance suitable for use as a key path in an
  /// instance of `Graph` where the key type is `UInt32`.
  ///
  /// The values in this collection, being swift-syntax node IDs, are never more
  /// than 32 bits wide.
  var keyPath: some RandomAccessCollection<UInt32> {
    let nybbles = stringValue
      .reversed().lazy
      .compactMap { UInt8(String($0), radix: 16) }

    return nybbles
      .enumerated()
      .flatMap { i, nybble in
        (0 ..< Self._bitsPerNybble).lazy
          .filter { (nybble & (1 << $0)) != 0 }
          .map { (i * Self._bitsPerNybble) + $0 }
          .map(UInt32.init)
      }
  }
}

// MARK: - Equatable, Hashable

extension __ExpressionID: Equatable, Hashable {}

#if DEBUG
// MARK: - CustomStringConvertible, CustomDebugStringConvertible

extension __ExpressionID: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    stringValue
  }

  public var debugDescription: String {
    #""\#(stringValue)" → \#(Array(keyPath))"#
  }
}
#endif

// MARK: - ExpressibleByStringLiteral

extension __ExpressionID: ExpressibleByStringLiteral {
  public init(stringLiteral: String) {
    stringValue = stringLiteral
  }
}

