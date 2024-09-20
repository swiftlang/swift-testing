//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftSyntax

extension SyntaxProtocol {
  /// Get an expression representing the unique ID of this syntax node as well
  /// as those of its parent nodes.
  ///
  /// - Parameters:
  ///   - effectiveRootNode: The node to treat as the root of the syntax tree
  ///     for the purposes of generating a value.
  ///
  /// - Returns: An expression representing a bitmask of node IDs including this
  ///   node's and all ancestors (up to but excluding `effectiveRootNode`)
  ///   encoded as an instance of `String`.
  func expressionID(rootedAt effectiveRootNode: some SyntaxProtocol) -> ExprSyntax {
    // Construct the unique chain of node IDs that leads to the node being
    // rewritten.
    var nodeIDChain = sequence(first: Syntax(self), next: \.parent)
      .map { $0.id.indexInTree.toOpaque() }

#if DEBUG
    assert(nodeIDChain.sorted() == nodeIDChain.reversed(), "Child node had lower ID than parent node in sequence \(nodeIDChain). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    for id in nodeIDChain {
      assert(id <= UInt32.max, "Node ID \(id) was not a 32-bit integer. Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    }
#endif

    // The highest ID in the chain determines the number of bits needed, and the
    // ID of this node will always be the highest (per the assertion above.)
    let maxID = id.indexInTree.toOpaque()
#if DEBUG
    assert(nodeIDChain.contains(maxID), "ID \(maxID) of syntax node '\(self.trimmed)' was not found in its node ID chain \(nodeIDChain). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
#endif

    // Adjust all node IDs downards by the effective root node's ID, then remove
    // the effective root node and its ancestors. This allows us to use lower
    // bit ranges than we would if we always included those nodes.
    do {
      let effRootNodeID = effectiveRootNode.id.indexInTree.toOpaque()
      if let effRootNodeIndex = nodeIDChain.lastIndex(of: effRootNodeID) {
        nodeIDChain = nodeIDChain[..<effRootNodeIndex].map { $0 - effRootNodeID }
      }
    }

    // Convert the node IDs in the chain to bits in a bit mask.
    let bitsPerWord = UInt64(UInt64.bitWidth)
    var words = [UInt64](
      repeating: 0,
      count: Int(((maxID + 1) + (bitsPerWord - 1)) / bitsPerWord)
    )
    for id in nodeIDChain {
      let (word, bit) = id.quotientAndRemainder(dividingBy: bitsPerWord)
      words[Int(word)] |= (1 << bit)
    }

    // Convert the bits to a hexadecimal string.
    let bitsPerNybble = 4
    let nybblesPerWord = UInt64.bitWidth / bitsPerNybble
    var id: String = words.map { word in
      let result = String(word, radix: 16)
      return String(repeating: "0", count: nybblesPerWord - result.count) + result
    }.joined()

    // Drop any redundant leading zeroes from the string literal.
    id = String(id.drop { $0 == "0" })

    return ExprSyntax(StringLiteralExprSyntax(content: id))
  }
}
