//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing a tree with key-value semantics.
///
/// Each node in the tree represented by an instance of ``Graph`` is also an
/// instance of ``Graph``. Each node contains a leaf value, ``Graph.value``, as
/// well as zero or more child nodes in the ``Graph.children`` property.
///
/// A sparse graph can be constructed by specifying an optional type as the
/// generic value type `V`. Additional member functions are available when a
/// graph has optional values.
///
/// This type is effectively equivalent to a [trie](https://en.wikipedia.org/wiki/Trie),
/// but the order of its children is not preserved.
///
/// This type is not part of the public interface of the testing library.
struct Graph<K, V> where K: Hashable {
  /// The leaf value of this graph node.
  var value: V

  /// The child nodes of this graph node.
  var children: [K: Graph]

  /// Initialize an instance of this type with the specified root value and
  /// child nodes.
  ///
  /// - Parameters:
  ///   - value: The root value of the new graph.
  ///   - children: The first-order child nodes of the new graph.
  init(value: V, children: [K: Graph] = [:]) {
    self.value = value
    self.children = children
  }

  /// Get the subgraph at the node identified by the specified sequence of keys.
  ///
  /// - Parameters:
  ///   - keyPath: A sequence of keys leading to the node of interest.
  ///
  /// - Returns: The subgraph at the specified node, or `nil` if the node is not
  ///   present.
  ///
  /// - Complexity: O(*n*) where *n* is the number of elements in `keyPath`.
  func subgraph(at keyPath: some Collection<K>) -> Self? {
    if let key = keyPath.first {
      return children[key]?.subgraph(at: keyPath.dropFirst())
    }
    return self
  }

  /// Get the subgraph at the node identified by the specified sequence of keys.
  ///
  /// - Parameters:
  ///   - keyPath: A sequence of keys leading to the node of interest.
  ///
  /// - Returns: The subgraph at the specified node, or `nil` if the node is not
  ///   present.
  ///
  /// - Complexity: O(*n*) where *n* is the number of elements in `keyPath`.
  func subgraph(at keyPath: K...) -> Self? {
    subgraph(at: keyPath)
  }

  /// Get the leaf value at the node identified by the specified sequence of
  /// keys.
  ///
  /// - Parameters:
  ///   - keyPath: A sequence of keys leading to the node of interest.
  ///
  /// - Returns: The value at the specified node, or `nil` if the node is not
  ///   present.
  ///
  /// - Complexity: O(*n*) where *n* is the number of elements in `keyPath`.
  subscript(keyPath: some Collection<K>) -> V? {
    subgraph(at: keyPath)?.value
  }

  /// Get the leaf value at the node identified by the specified sequence of
  /// keys.
  ///
  /// - Parameters:
  ///   - keyPath: A sequence of keys leading to the node of interest.
  ///
  /// - Returns: The value at the specified node, or `nil` if the node is not
  ///   present.
  ///
  /// - Complexity: O(*n*) where *n* is the number of elements in `keyPath`.
  subscript(keyPath: K...) -> V? {
    self[keyPath]
  }

  /// Set the leaf value at the node identified by the specified sequence of
  /// keys.
  ///
  /// - Parameters:
  ///   - newValue: The leaf value to set at the specified node.
  ///   - keyPath: A sequence of keys leading to the node of interest.
  ///
  /// - Returns: The old value at `keyPath`, or `nil` if no value was present.
  ///
  /// If there is no node at the specified key path or at a key path
  /// intermediate to it, the graph is not modified. To add a value when none
  /// previously exists, use ``insertValue(_:at:intermediateValue:)``.
  ///
  /// - Complexity: O(*m* + *n*) where *n* is the number of elements in
  ///   `keyPath` and *m* is the number of children at the penultimate node in
  ///   `keyPath`.
  @discardableResult
  mutating func updateValue(_ newValue: V, at keyPath: some Collection<K>) -> V? {
    let result: V?

    if let key = keyPath.first {
      result = children[key]?.updateValue(newValue, at: keyPath.dropFirst())
    } else {
      result = value
      value = newValue
    }

    return result
  }

  /// Insert a new leaf value at the node identified by the specified sequence
  /// of keys.
  ///
  /// - Parameters:
  ///   - newValue: The leaf value to set at the specified node.
  ///   - keyPath: A sequence of keys leading to the node of interest.
  ///   - intermediateValue: A value to use when creating nodes intermediate to
  ///     the one identified by `keyPath`.
  ///
  /// - Returns: The old value at `keyPath`, or `nil` if no value was present.
  ///
  /// If there is no node at the specified key path or at a key path
  /// intermediate to it, one is inserted with the leaf value
  /// `intermediateValue`. If a node at `keyPath` already exists, its leaf value
  /// is updated.
  ///
  /// - Complexity: O(*m* + *n*) where *n* is the number of elements in
  ///   `keyPath` and *m* is the number of children at the penultimate node in
  ///   `keyPath`.
  @discardableResult
  mutating func insertValue(_ newValue: V, at keyPath: some Collection<K>, intermediateValue: V) -> V? {
    let result: V?

    if let key = keyPath.first {
      if var child = children[key] {
        result = child.insertValue(newValue, at: keyPath.dropFirst(), intermediateValue: intermediateValue)
        children[key] = child
      } else {
        // There was no value at this node, so create one, but return nil to
        // indicate there was no previous value (otherwise we'll end up
        // returning the value we just created.)
        var child = Graph(value: intermediateValue)
        child.insertValue(newValue, at: keyPath.dropFirst(), intermediateValue: intermediateValue)
        children[key] = child
        result = nil
      }
    } else {
      result = value
      value = newValue
    }

    return result
  }

  /// Remove the leaf value at the node identified by the specified sequence of
  /// keys.
  ///
  /// - Parameters:
  ///   - keyPath: A sequence of keys leading to the node of interest.
  ///
  /// - Returns: The old value at `keyPath`, or `nil` if no value was present.
  ///
  /// If a node is present at the specified key path, it is removed. Any child
  /// nodes are also removed. If `keyPath` is empty (i.e. it refers to `self`,
  /// `nil` is returned and `self` is not modified.
  ///
  /// - Complexity: O(*m* + *n*) where *n* is the number of elements in
  ///   `keyPath` and *m* is the number of children at the penultimate node in
  ///   `keyPath`.
  @discardableResult
  mutating func removeValue(at keyPath: some Collection<K>) -> V? {
    let result: V?

    if let key = keyPath.first {
      let childKeyPath = keyPath.dropFirst()
      if childKeyPath.isEmpty {
        result = children.removeValue(forKey: key)?.value
      } else {
        result = children[key]?.removeValue(at: childKeyPath)
      }
    } else {
      result = nil
    }

    return result
  }
}

// MARK: - Sendable

extension Graph: Sendable where K: Sendable, V: Sendable {}

// MARK: - Sparse graph operations

extension Graph {
  /// Initialize an instance of this type with the specified child nodes.
  ///
  /// - Parameters:
  ///   - children: The first-order child nodes of the new graph.
  ///
  /// The root value is initialized to `nil`. This initializer produces a sparse
  /// graph where nodes may have no value but child nodes may still exist.
  init<U>(children: [K: Graph] = [:]) where V == U? {
    self.init(value: nil, children: children)
  }

  /// Set the leaf value at the node identified by the specified sequence of
  /// keys.
  ///
  /// - Parameters:
  ///   - newValue: The leaf value to set at the specified node.
  ///   - keyPath: A sequence of keys leading to the node of interest.
  ///
  /// - Returns: The old value at `keyPath`, or `nil` if no value was present.
  ///
  /// If there is no node at the specified key path or at a key path
  /// intermediate to it, the graph is not modified. To add a value when none
  /// previously exists, use ``insertValue(_:at:intermediateValue:)``.
  ///
  /// - Complexity: O(*m* + *n*) where *n* is the number of elements in
  ///   `keyPath` and *m* is the number of children at the penultimate node in
  ///   `keyPath`.
  @discardableResult
  mutating func updateValue<U>(_ newValue: V, at keyPath: some Collection<K>) -> V where V == U? {
    (updateValue(newValue, at: keyPath) as V?) ?? nil
  }

  /// Insert a new leaf value at the node identified by the specified sequence
  /// of keys.
  ///
  /// - Parameters:
  ///   - newValue: The leaf value to set at the specified node.
  ///   - keyPath: A sequence of keys leading to the node of interest.
  ///   - intermediateValue: A value to use when creating nodes intermediate to
  ///     the one identified by `keyPath`.
  ///
  /// - Returns: The old value at `keyPath`, or `nil` if no value was present.
  ///
  /// If there is no node at the specified key path or at a key path
  /// intermediate to it, one is inserted with a `nil` leaf value. If a node at
  /// `keyPath` already exists, its leaf value is updated.
  ///
  /// - Complexity: O(*m* + *n*) where *n* is the number of elements in
  ///   `keyPath` and *m* is the number of children at the penultimate node in
  ///   `keyPath`.
  @discardableResult
  mutating func insertValue<C, U>(_ newValue: V, at keyPath: C) -> V where C: Collection, C.Element == K, V == U? {
    insertValue(newValue, at: keyPath, intermediateValue: nil) ?? nil
  }

  /// Remove the leaf value at the node identified by the specified sequence
  /// of keys.
  ///
  /// - Parameters:
  ///   - keyPath: A sequence of keys leading to the node of interest.
  ///   - keepingChildren: Whether or not to keep children of the node where the
  ///     value was removed.
  ///
  /// - Returns: The old value at `keyPath`, or `nil` if no value was present.
  ///
  /// If a node is present at the specified key path, it is removed. If
  /// `keepingChildren` is `false`, any child nodes are also removed.
  ///
  /// - Complexity: O(*m* + *n*) where *n* is the number of elements in
  ///   `keyPath` and *m* is the number of children at the penultimate node in
  ///   `keyPath`.
  @discardableResult
  mutating func removeValue<U>(at keyPath: some Collection<K>, keepingChildren: Bool = false) -> V where V == U? {
    let result: V

    if keepingChildren {
      result = updateValue(nil, at: keyPath)
    } else if keyPath.isEmpty {
      result = value
      value = nil
      children.removeAll(keepingCapacity: false)
    } else {
      result = (removeValue(at: keyPath) as V?) ?? nil
    }

    return result
  }
}

// MARK: - Sequence-like members

extension Graph {
  /// The element type of a graph: a tuple containing a key path and the value
  /// at that key path.
  typealias Element = (keyPath: [K], value: V)

  /// A value less than or equal to the number of nodes in the graph.
  ///
  /// The value of this property counts `self` as a node, so it is always at
  /// least `1`.
  ///
  /// - Complexity: O(1)
  var underestimatedCount: Int {
    1 + children.count
  }

  /// The number of nodes in the graph.
  ///
  /// The value of this property counts `self` as a node, so it is always at
  /// least `1`.
  ///
  /// - Complexity: O(*n*), where *n* is the number of nodes in the graph.
  var count: Int {
    1 + children.reduce(into: 0) { count, child in
      count += child.value.underestimatedCount
    }
  }
}

// MARK: - Functional programming

extension Graph {
  /// The recursive implementation of `forEach(_:)`.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to use for the root node when passing it to
  ///     `body`.
  ///   - body: A closure that is invoked once per element in the graph. The key
  ///     path and leaf value of each node are passed to the closure.
  ///
  /// - Throws: Whatever is thrown by `body`.
  private func _forEach(keyPath: [K], _ body: (Element) throws -> Void) rethrows -> Void {
    try body((keyPath, value))
    for (key, child) in children {
      var childKeyPath = keyPath
      childKeyPath.append(key)
      try child._forEach(keyPath: childKeyPath, body)
    }
  }

  /// The recursive implementation of `forEach(_:)`.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to use for the root node when passing it to
  ///    `body`.
  ///   - body: A closure that is invoked once per element in the graph. The
  ///     key path and leaf value of each node are passed to the closure.
  ///
  /// - Throws: Whatever is thrown by `body`.
  private func _forEach(keyPath: [K], _ body: (Element) async throws -> Void) async rethrows -> Void {
    try await body((keyPath, value))
    for (key, child) in children {
      var childKeyPath = keyPath
      childKeyPath.append(key)
      try await child._forEach(keyPath: childKeyPath, body)
    }
  }

  /// Iterate over the nodes in a graph.
  ///
  /// - Parameters:
  ///   - body: A closure that is invoked once per element in the graph. The
  ///     key path and leaf value of each node are passed to the closure.
  ///
  /// - Throws: Whatever is thrown by `body`.
  ///
  /// This function iterates depth-first.
  func forEach(_ body: (Element) throws -> Void) rethrows -> Void {
    try _forEach(keyPath: []) {
      try body(($0, $1))
    }
  }

  /// Iterate over the nodes in a graph.
  ///
  /// - Parameters:
  ///   - body: A closure that is invoked once per element in the graph. The
  ///     key path and leaf value of each node are passed to the closure.
  ///
  /// - Throws: Whatever is thrown by `body`.
  ///
  /// This function iterates depth-first.
  func forEach(_ body: (Element) async throws -> Void) async rethrows -> Void {
    try await _forEach(keyPath: []) {
      try await body(($0, $1))
    }
  }

  /// A sequence containing only the values at the specified key path.
  ///
  /// - Parameters:
  ///   - keyPath: The key path whose values should be included.
  ///
  /// - Returns: A sequence containing only the values at the specified key
  ///   path.
  ///
  /// If there is no value for some key in the specified key path, `nil` is
  /// used as the value corresponding to that key.
  func takeValues(at keyPath: some Collection<K>) -> some Sequence<V?> {
    let state = (
      graph: self as Graph?,
      nextKeyIndex: keyPath.startIndex
    )
    return sequence(state: state) { state in
      guard state.nextKeyIndex < keyPath.endIndex else {
        return .none
      }
      let key = keyPath[state.nextKeyIndex]
      state.nextKeyIndex = keyPath.index(after: state.nextKeyIndex)

      state.graph = state.graph?.children[key]
      if let childGraph = state.graph {
        return childGraph.value
      }
      return .some(nil)
    }
  }

  /// Create a new graph containing only the nodes that have non-`nil` values as
  /// the result of transformation by the given closure.
  ///
  /// - Parameters:
  ///   - transform: A closure that is invoked once per element in the graph.
  ///     The leaf value of each node is passed to this closure and its result
  ///     is used as the corresponding value in the new graph. If the result is
  ///     `nil`, the node and all of its child nodes are omitted from the new
  ///     graph.
  ///
  /// - Returns: A graph containing the transformed nodes of this graph at the
  ///   same key paths, with `nil` values omitted.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func compactMapValues<U>(_ transform: (V) throws -> U?) rethrows -> Graph<K, U>? {
    try compactMapValues {
      try transform($0).map { ($0, false) }
    }
  }

  /// Create a new graph containing only the nodes that have non-`nil` values as
  /// the result of transformation by the given closure.
  ///
  /// - Parameters:
  ///   - transform: A closure that is invoked once per element in the graph.
  ///     The leaf value of each node is passed to this closure and its result
  ///     is used as the corresponding value in the new graph. If the result is
  ///     `nil`, the node and all of its child nodes are omitted from the new
  ///     graph.
  ///
  /// - Returns: A graph containing the transformed nodes of this graph at the
  ///   same key paths, with `nil` values omitted.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func compactMapValues<U>(_ transform: (V) async throws -> U?) async rethrows -> Graph<K, U>? {
    try await compactMapValues {
      try await transform($0).map { ($0, false) }
    }
  }

  /// Create a new graph containing only the nodes that have non-`nil` values as
  /// the result of transformation by the given closure, with the option to
  /// recursively apply said result to all descendants of each node.
  ///
  /// - Parameters:
  ///   - transform: A closure that is invoked once per element in the graph.
  ///     The leaf value of each node is passed to this closure. The result of
  ///     the closure is a tuple containing the new value and specifying whether
  ///     or not the new value should also be applied to each descendant node.
  ///     If `true`, `transform` is not invoked for those descendant nodes. If
  ///     the result is `nil`, the node and all of its child nodes are omitted
  ///     from the new graph.
  ///
  /// - Returns: A graph containing the transformed nodes of this graph at the
  ///   same key paths, with `nil` values omitted.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func compactMapValues<U>(_ transform: (V) throws -> (U, recursivelyApply: Bool)?) rethrows -> Graph<K, U>? {
    guard let (newValue, recursivelyApply) = try transform(value) else {
      return nil
    }

    var newChildren = [K: Graph<K,U>]()
    newChildren.reserveCapacity(children.count)
    for (key, child) in children {
      if recursivelyApply {
        newChildren[key] = child.compactMapValues { _ in (newValue, true) }
      } else {
        newChildren[key] = try child.compactMapValues(transform)
      }
    }

    return Graph<K, U>(value: newValue, children: newChildren)
  }

  /// Create a new graph containing only the nodes that have non-`nil` values as
  /// the result of transformation by the given closure, with the option to
  /// recursively apply said result to all descendants of each node.
  ///
  /// - Parameters:
  ///   - transform: A closure that is invoked once per element in the graph.
  ///     The leaf value of each node is passed to this closure. The result of
  ///     the closure is a tuple containing the new value and specifying whether
  ///     or not the new value should also be applied to each descendant node.
  ///     If `true`, `transform` is not invoked for those descendant nodes. If
  ///     the result is `nil`, the node and all of its child nodes are omitted
  ///     from the new graph.
  ///
  /// - Returns: A graph containing the transformed nodes of this graph at the
  ///   same key paths, with `nil` values omitted.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func compactMapValues<U>(_ transform: (V) async throws -> (U, recursivelyApply: Bool)?) async rethrows -> Graph<K, U>? {
    guard let (newValue, recursivelyApply) = try await transform(value) else {
      return nil
    }

    var newChildren = [K: Graph<K,U>]()
    newChildren.reserveCapacity(children.count)
    for (key, child) in children {
      if recursivelyApply {
        newChildren[key] = child.compactMapValues { _ in (newValue, true) }
      } else {
        newChildren[key] = try await child.compactMapValues(transform)
      }
    }

    return Graph<K, U>(value: newValue, children: newChildren)
  }

  /// Create a new graph containing the nodes of this graph with the values
  /// transformed by the given closure.
  ///
  /// - Parameters:
  ///   - transform: A closure that is invoked once per element in the graph.
  ///     The leaf value of each node is passed to this closure and its result
  ///     is used as the corresponding value in the new graph.
  ///
  /// - Returns: A graph containing the transformed nodes of this graph at the
  ///   same key paths.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func mapValues<U>(_ transform: (V) throws -> U) rethrows -> Graph<K, U> {
    try compactMapValues(transform)!
  }

  /// Create a new graph containing the nodes of this graph with the values
  /// transformed by the given closure.
  ///
  /// - Parameters:
  ///   - transform: A closure that is invoked once per element in the graph.
  ///     The leaf value of each node is passed to this closure and its result
  ///     is used as the corresponding value in the new graph.
  ///
  /// - Returns: A graph containing the transformed nodes of this graph at the
  ///   same key paths.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func mapValues<U>(_ transform: (V) async throws -> U) async rethrows -> Graph<K, U> {
    try await compactMapValues(transform)!
  }

  /// Create a new graph containing the nodes of this graph with the values
  /// transformed by the given closure, with the option to recursively apply
  /// the result of that transformation to all descendants of each node.
  ///
  /// - Parameters:
  ///   - transform: A closure that is invoked once per element in the graph.
  ///     The leaf value of each node is passed to this closure. The result of
  ///     the closure is a tuple containing the new value and specifying whether
  ///     or not the new value should also be applied to each descendant node.
  ///     If `true`, `transform` is not invoked for those descendant nodes.
  ///
  /// - Returns: A graph containing the transformed nodes of this graph at the
  ///   same key paths.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func mapValues<U>(_ transform: (V) throws -> (U, recursivelyApply: Bool)) rethrows -> Graph<K, U> {
    try compactMapValues(transform)!
  }

  /// Create a new graph containing the nodes of this graph with the values
  /// transformed by the given closure, with the option to recursively apply
  /// the result of that transformation to all descendants of each node.
  ///
  /// - Parameters:
  ///   - transform: A closure that is invoked once per element in the graph.
  ///     The leaf value of each node is passed to this closure. The result of
  ///     the closure is a tuple containing the new value and specifying whether
  ///     or not the new value should also be applied to each descendant node.
  ///     If `true`, `transform` is not invoked for those descendant nodes.
  ///
  /// - Returns: A graph containing the transformed nodes of this graph at the
  ///   same key paths.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func mapValues<U>(_ transform: (V) async throws -> (U, recursivelyApply: Bool)) async rethrows -> Graph<K, U> {
    try await compactMapValues(transform)!
  }

  /// Create an array containing the results of mapping the given closure over
  /// the graph's nodes.
  ///
  /// - Parameters:
  ///   - body: A closure that is invoked once per element in the graph. The key
  ///     path and leaf value of each node are passed to the closure. The
  ///     closure's result is used as the corresponding value in the resulting
  ///     array.
  ///
  /// - Returns: An array containing the transformed nodes of this graph.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func map<U>(_ transform: (Element) throws -> U) rethrows -> [U] {
    try compactMap(transform)
  }

  /// Create an array containing the results of mapping the given closure over
  /// the graph's nodes.
  ///
  /// - Parameters:
  ///   - body: A closure that is invoked once per element in the graph. The key
  ///     path and leaf value of each node are passed to the closure. The
  ///     closure's result is used as the corresponding value in the resulting
  ///     array.
  ///
  /// - Returns: An array containing the transformed nodes of this graph.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func map<U>(_ transform: (Element) async throws -> U) async rethrows -> [U] {
    try await compactMap(transform)
  }

  /// Create an array containing the non-`nil` results of calling the given
  /// transformation with each node of this graph.
  ///
  /// - Parameters:
  ///   - body: A closure that is invoked once per element in the graph. The key
  ///     path and leaf value of each node are passed to the closure. The
  ///     closure's result is used as the corresponding value in the resulting
  ///     array. If the result is `nil`, the node's value is omitted from the
  ///     resulting array.
  ///
  /// - Returns: An array of the non-`nil` results of calling `transform` with
  ///   each node of the graph.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func compactMap<U>(_ transform: (Element) throws -> U?) rethrows -> [U] {
    var result = [U]()

    try forEach { keyPath, value in
      if let newValue = try transform((keyPath, value)) {
        result.append(newValue)
      }
    }

    return result
  }

  /// Create an array containing the non-`nil` results of calling the given
  /// transformation with each node of this graph.
  ///
  /// - Parameters:
  ///   - body: A closure that is invoked once per element in the graph. The key
  ///     path and leaf value of each node are passed to the closure. The
  ///     closure's result is used as the corresponding value in the resulting
  ///     array. If the result is `nil`, the node's value is omitted from the
  ///     resulting array.
  ///
  /// - Returns: An array of the non-`nil` results of calling `transform` with
  ///   each node of the graph.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func compactMap<U>(_ transform: (Element) async throws -> U?) async rethrows -> [U] {
    var result = [U]()

    try await forEach { keyPath, value in
      if let newValue = try await transform((keyPath, value)) {
        result.append(newValue)
      }
    }

    return result
  }

  /// Create an array containing the concatenated results of calling the given
  /// transformation with each node of this graph.
  ///
  /// - Parameters:
  ///   - body: A closure that is invoked once per element in the graph. The key
  ///     path and leaf value of each node are passed to the closure. The
  ///     elements in the closure's result are added to the resulting array.
  ///
  /// - Returns: The resulting flattened array.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func flatMap<S>(_ transform: (Element) throws -> S) rethrows -> [S.Element] where S: Sequence {
    try map(transform).flatMap { $0 }
  }

  /// Create an array containing the concatenated results of calling the given
  /// transformation with each node of this graph.
  ///
  /// - Parameters:
  ///   - body: A closure that is invoked once per element in the graph. The key
  ///     path and leaf value of each node are passed to the closure. The
  ///     elements in the closure's result are added to the resulting array.
  ///
  /// - Returns: The resulting flattened array.
  ///
  /// - Throws: Whatever is thrown by `transform`.
  ///
  /// This function iterates depth-first.
  func flatMap<S>(_ transform: (Element) async throws -> S) async rethrows -> [S.Element] where S: Sequence {
    try await map(transform).flatMap { $0 }
  }
}

/// Creates a graph whose values are pairs built out of two underlying graphs.
///
/// - Parameters:
///   - graph1: The first graph to zip.
///   - graph2: The second graph to zip.
///
/// - Returns: A graph whose values are tuple pairs, where the elements of each
///   pair are corresponding elements of `graph1` and `graph2`. If an element is
///   not present in one graph or the other at a particular keypath, it is
///   omitted from the result.
func zip<K, V1, V2>(_ graph1: Graph<K, V1>, _ graph2: Graph<K, V2>) -> Graph<K, (V1, V2)> {
  var children = [K: Graph<K, (V1, V2)>]()
  do {
    let children1 = graph1.children
    let children2 = graph2.children

    children.reserveCapacity(min(children1.count, children2.count))
    for (key, childGraph1) in children1 {
      if let childGraph2 = children2[key] {
        children[key] = zip(childGraph1, childGraph2)
      }
    }
  }

  return Graph(value: (graph1.value, graph2.value), children: children)
}
