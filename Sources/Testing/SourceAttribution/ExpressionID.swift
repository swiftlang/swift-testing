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
/// This type tries to optimize for expressions in shallow syntax trees whose
/// unique identifiers require 64 bits or fewer. Wider unique identifiers are
/// stored as arrays of 64-bit words. In the future, this type may use
/// [`StaticBigInt`](https://developer.apple.com/documentation/swift/staticbigint)
/// to represent expression identifiers instead.
///
/// - Warning: This type is used to implement the `#expect()` and `#require()`
///   macros. Do not use it directly.
public struct __ExpressionID: Sendable {
  /// The ID of the root node in an expression graph.
  static var root: Self {
    Self(elements: .none)
  }

  /// An enumeration that attempts to efficiently store the key path elements
  /// corresponding to an expression ID.
  fileprivate enum Elements: Sendable {
    /// This ID does not use any words.
    ///
    /// This case represents the root node in a syntax tree. An instance of
    /// `__ExpressionID` storing this case is implicitly equal to `.root`.
    case none

    /// This ID packs its corresponding key path value into a single word whose
    /// value is not `0`.
    case packed(_ word: UInt64)

    /// This ID contains key path elements that do not fit in a 64-bit integer,
    /// so they are not packed and map directly to the represented key path.
    indirect case keyPath(_ keyPath: [UInt32])
  }

  /// The elements of this identifier.
  fileprivate var elements: Elements
}

// MARK: - Equatable, Hashable

extension __ExpressionID: Equatable, Hashable {}
extension __ExpressionID.Elements: Equatable, Hashable {}

// MARK: - Collection

extension __ExpressionID {
  /// A type representing the elements in a key path produced from the unique
  /// identifier of an expression.
  ///
  /// Instances of this type can be used to produce keys and key paths for an
  /// instance of `Graph` whose key type is `UInt32`.
  private struct _KeyPathForGraph: Collection {
    /// Underlying storage for the collection.
    var elements: __ExpressionID.Elements

    var count: Int {
      switch elements {
      case .none:
        0
      case let .packed(word):
        word.nonzeroBitCount
      case let .keyPath(keyPath):
        keyPath.count
      }
    }

    var startIndex: Int {
      switch elements {
      case .none, .keyPath:
        0
      case let .packed(word):
        word.trailingZeroBitCount
      }
    }

    var endIndex: Int {
      switch elements {
      case .none:
        0
      case .packed:
        UInt64.bitWidth
      case let .keyPath(keyPath):
        keyPath.count
      }
    }

    func index(after i: Int) -> Int {
      let uncheckedNextIndex = i + 1
      switch elements {
      case .none, .keyPath:
        return uncheckedNextIndex
      case let .packed(word):
        // Mask off the low bits including the one at `i`. The trailing zero
        // count of the resulting value equals the next actual bit index.
        let maskedWord = word & (~0 << uncheckedNextIndex)
        return maskedWord.trailingZeroBitCount
      }
    }

    subscript(position: Int) -> UInt32 {
      switch elements {
      case .none:
        fatalError("Unreachable")
      case .packed:
        UInt32(position)
      case let .keyPath(keyPath):
        keyPath[position]
      }
    }
  }

  /// A representation of this instance suitable for use as a key path in an
  /// instance of `Graph` where the key type is `UInt32`.
  ///
  /// The values in this collection, being swift-syntax node IDs, are never more
  /// than 32 bits wide.
  var keyPathRepresentation: some Collection<UInt32> {
    _KeyPathForGraph(elements: elements)
  }
}

#if DEBUG
// MARK: - CustomStringConvertible, CustomDebugStringConvertible

extension __ExpressionID: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    switch elements {
    case .none:
      return "0"
    case let .packed(word):
      return "0x\(String(word, radix: 16))"
    case let .keyPath(keyPath):
      let components: String = keyPath.lazy
        .map { String($0, radix: 16) }
        .joined(separator: ",")
      return "[\(components)]"
    }
  }

  public var debugDescription: String {
    #""\#(description)" → \#(Array(keyPathRepresentation))"#
  }
}
#endif

// MARK: - ExpressibleByIntegerLiteral

extension __ExpressionID: ExpressibleByIntegerLiteral {
  public init(integerLiteral: UInt64) {
    if integerLiteral == 0 {
      self.init(elements: .none)
    } else {
      self.init(elements: .packed(integerLiteral))
    }
  }

  public init(_ keyPath: UInt32...) {
    self.init(elements: .keyPath(keyPath))
  }
}
