//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftSyntax
import SwiftSyntaxMacros

/// A type responsible for constructing expression IDs during expansion of the
/// macros `#expect()` and `#require()`.
struct ExpressionIDBuilder<C> where C: MacroExpansionContext {
  /// The effective root node of the syntax tree from which expression IDs will
  /// be generated.
  var rootNode: Syntax

  /// The macro context in which the expression is being parsed.
  var context: C

  /// Initialize an instance of this type.
  ///
  /// - Parameters:
  ///   - rootNode: The effective root node of the syntax tree.
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// `rootNode` is automatically memoized so it has the lowest identifier of
  /// all nodes.
  init(rootedAt rootNode: some SyntaxProtocol, in context: C) {
    self.rootNode = Syntax(rootNode)
    self.context = context
    memoize(self.rootNode)
  }

  /// The set of IDs assigned to syntax nodes so far.
  private var _idMappings = [Syntax.ID: UInt64]()

  /// Memoize a node and generate its ID.
  ///
  /// - Parameters:
  ///   - node: The node to memoize.
  ///
  /// This function assigns the next available ID to `node` so that, when
  /// ``id(for:)`` or ``idExpression(for:)`` is called, the node's ID can be
  /// generated. If `node` has already been memoized, this function does
  /// nothing.
  mutating func memoize(_ node: some SyntaxProtocol) {
    if _idMappings[node.id] == nil {
      _idMappings[node.id] = UInt64(_idMappings.count)
    }
  }

  /// Generate a unique ID for the given syntax node.
  ///
  /// - Parameters:
  ///   - node: The node to generate an ID for.
  ///
  /// - Returns: A string encoding a unique ID for `node` and its place in the
  ///   syntax tree rooted at ``rootNode``.
  ///
  /// This function automatically memoizes `node`, then generates a unique ID
  /// string for it. Only its ancestors that have been memoized are represented
  /// in the resulting string.
  ///
  /// The effect of passing a node that does not have ``rootNode`` as an
  /// ancestor is undefined.
  mutating func idExpression(for node: some SyntaxProtocol) -> ExprSyntax {
    memoize(node)

    var ancestorIDs = sequence(first: Syntax(node), next: \.parent)
      .compactMap { _idMappings[$0.id] }

    // Adjust all node IDs downards by the root node's ID, then remove the root
    // node and its ancestors. This allows us to use lower bit ranges than we
    // would if we always included those nodes.
    if let rootNodeID = _idMappings[rootNode.id] {
      if let rootNodeIndex = ancestorIDs.lastIndex(of: rootNodeID) {
        ancestorIDs = ancestorIDs[..<rootNodeIndex].map { $0 - rootNodeID }
      }
    }

    guard let maxID = ancestorIDs.max() else {
      return ExprSyntax(StringLiteralExprSyntax(content: ""))
    }

    let bitsPerWord = UInt64(UInt64.bitWidth)
    let wordsNeeded = Int(((maxID + 1) + (bitsPerWord - 1)) / bitsPerWord)
    var words = [UInt64](repeating: 0, count: wordsNeeded)
    for id in ancestorIDs {
      let (word, bit) = id.quotientAndRemainder(dividingBy: bitsPerWord)
      words[Int(word)] |= (1 << bit)
    }

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
