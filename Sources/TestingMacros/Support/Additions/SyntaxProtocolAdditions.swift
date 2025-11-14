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
import SwiftSyntaxBuilder

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
    // Construct the unique sequence of node IDs that leads to the node being
    // rewritten.
    var ancestralNodeIDs = sequence(first: Syntax(self), next: \.parent)
      .map { $0.id.indexInTree.toOpaque() }
    
#if DEBUG
    assert(ancestralNodeIDs.sorted() == ancestralNodeIDs.reversed(), "Child node had lower ID than parent node in sequence \(ancestralNodeIDs). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    for id in ancestralNodeIDs {
      assert(id <= UInt32.max, "Node ID \(id) was not a 32-bit integer. Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    }

    // The highest ID in the sequence determines the number of bits needed, and
    // the ID of this node will always be the highest (per the assertion above.)
    let expectedMaxID = id.indexInTree.toOpaque()
    assert(ancestralNodeIDs.contains(expectedMaxID), "ID \(expectedMaxID) of syntax node '\(self.trimmed)' was not found in its node ID sequence \(ancestralNodeIDs). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
#endif
    
    // Adjust all node IDs downards by the effective root node's ID, then remove
    // the effective root node and its ancestors. This allows us to use lower
    // bit ranges than we would if we always included those nodes.
    do {
      let effRootNodeID = effectiveRootNode.id.indexInTree.toOpaque()
      if let effRootNodeIndex = ancestralNodeIDs.lastIndex(of: effRootNodeID) {
        ancestralNodeIDs = ancestralNodeIDs[..<effRootNodeIndex].map { $0 - effRootNodeID }
      }
    }

    let maxID = ancestralNodeIDs.max() ?? 0
    if maxID < UInt64.bitWidth {
      // Pack all the node IDs into a single integer value.
      let word = ancestralNodeIDs.reduce(into: UInt64(0)) { word, id in
        word |= (1 << id)
      }
      return ExprSyntax(IntegerLiteralExprSyntax(word, radix: .hex))

    } else {
      // Some ID exceeds what we can fit in a single literal, so just produce an
      // array of node IDs instead.
      return ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: TypeExprSyntax(
            type: MemberTypeSyntax(
              baseType: IdentifierTypeSyntax(name: .identifier("Testing")),
              name: .identifier("__ExpressionID")
            )
          ),
          leftParen: .leftParenToken(),
          rightParen: .rightParenToken()
        ) {
          for nodeID in ancestralNodeIDs {
            LabeledExprSyntax(expression: IntegerLiteralExprSyntax(nodeID))
          }
        }
      )
    }
  }
}
