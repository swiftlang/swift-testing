//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that describes the difference between two values as a sequence of
/// insertions, deletions, or unmodified elements.
/// 
/// To ensure that ``Difference`` can always conform to `Sendable`, the elements
/// in an instance of this type are stored as strings rather than as their
/// original types. They are converted to strings using
/// ``Swift/String/init(describingForTest:)``. Types can implement
/// ``CustomTestStringConvertible`` to customize how they appear in the
/// description of an instance of this type.
@_spi(ExperimentalEventHandling)
public struct Difference: Sendable {
  /// An enumeration representing the kinds of change that can occur during
  /// diffing.
  enum ElementKind: Sendable {
    /// The element was inserted.
    case insert

    /// The element was removed.
    case remove

    /// The element replaced a previous value.
    ///
    /// - Parameters:
    ///   - oldValue: The old value at this position.
    case replace(oldValue: String)
  }

  /// A type representing an element of a collection that may have been changed
  /// after diffing was applied.
  ///
  /// This type roughly approximates `CollectionDifference.Change`, however it
  /// is used to track _all_ elements in the collection, not just those that
  /// have changed, allowing for insertion of "marker" elements where removals
  /// occurred.
  typealias Element = (value: String, kind: ElementKind?)

  /// The changed elements from the comparison.
  var elements = [Element]()

  init(elements: some Sequence<Element>) {
    self.elements = Array(elements)
  }

  /// Initialize an instance of this type by comparing two collections.
  ///
  /// - Parameters:
  ///   - lhs: The "old" state of the collection to compare.
  ///   - rhs: The "new" state of the collection to compare.
  init?<T, U>(from lhs: T, to rhs: U) {
    let lhsDump = String(describingForTestComparison: lhs)
      .split(whereSeparator: \.isNewline)
      .map(String.init)
    let rhsDump = String(describingForTestComparison: rhs)
      .split(whereSeparator: \.isNewline)
      .map(String.init)

    guard lhsDump.count > 1 || rhsDump.count > 1 else {
      return nil
    }

    // Compute the difference between the two elements. Sort the resulting set
    // of changes by their offsets, and ensure that insertions come before
    // removals located at the same offset. This helps to ensure that the offset
    // values do not drift as we walk the changeset.
    let difference = rhsDump.difference(from: lhsDump)

    // Walk the initial string and slowly transform it into the final string.
    // Add an additional "scratch" string that is used to store a removal marker
    // if the last character is removed.
    var result: [[Element]] = lhsDump.map { [($0, nil)] } + CollectionOfOne([])
    for change in difference.removals.reversed() {
      // Remove the character at the specified index, then re-insert it into the
      // slot at the previous index (with the marker character applied.) The
      // previous index will then contain whatever character it already
      // contained after the character representing this removal.
      result.remove(at: change.offset)
      result[change.offset].insert((change.element, kind: .remove), at: 0)
    }
    for change in difference.insertions {
      // Insertions can occur verbatim by inserting a new substring at the
      // specified offset.
      result.insert([(change.element, kind: .insert)], at: change.offset)
    }

    // Flatten the arrays of arrays of elements into a single array, then merge
    // pairs of removals/insertions (i.e. where an element was replaced with
    // another element) because it's easier to do after the array of arrays has
    // been flatted.
    let elements: some Sequence<Element> = result.lazy
      .flatMap { $0 }
      .reduce(into: []) { result, element in
        if element.kind == .remove, let previous = result.last, previous.kind == .insert {
          result[result.index(before: result.endIndex)] = (previous.value, .replace(oldValue: element.value))
        } else {
          result.append(element)
        }
      }

    self.init(elements: elements)
  }
}

// MARK: - Equatable

extension Difference.ElementKind: Equatable {}

// MARK: - CustomStringConvertible

extension Difference: CustomStringConvertible {
  public var description: String {
    // Show individual lines of the text with leading + or - characters to
    // indicate insertions and removals respectively.
    // FIXME: better descriptive output for one-line strings.
    let diffCount = elements.lazy
      .filter { $0.kind != nil }
      .count
    return "\(diffCount.counting("change")):\n" + elements.lazy
      .flatMap { element in
        switch element.kind {
        case nil:
          ["  \(element.value)"]
        case .insert:
          ["+ \(element.value)"]
        case .remove:
          ["- \(element.value)"]
        case let .replace(oldValue):
          [
            "- \(oldValue)",
            "+ \(element.value)"
          ]
        }
      }.joined(separator: "\n")
  }
}
