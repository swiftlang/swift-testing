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
  ///   - describingForTest: Whether or not to convert values in `lhs` and `rhs`
  ///     to strings using ``Swift/String/init(describingForTest:)``.
  init<T, U>(from lhs: T, to rhs: U, describingForTest: Bool = true)
  where T: BidirectionalCollection, T.Element: Equatable, U: BidirectionalCollection, T.Element == U.Element {
    // Compute the difference between the two elements. Sort the resulting set
    // of changes by their offsets, and ensure that insertions come before
    // removals located at the same offset. This helps to ensure that the offset
    // values do not drift as we walk the changeset.
    let difference = rhs.difference(from: lhs)

    // Walk the initial string and slowly transform it into the final string.
    // Add an additional "scratch" string that is used to store a removal marker
    // if the last character is removed.
    var result: [[(value: T.Element, kind: ElementKind?)]] = lhs.map { [($0, nil)] } + CollectionOfOne([])
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

    let describe: (T.Element) -> String = if describingForTest {
      String.init(describingForTest:)
    } else {
      String.init(describing:)
    }

    // Flatten the arrays of arrays of elements into a single array and convert
    // values to strings. Finally, merge pairs of removals/insertions (i.e.
    // where an element was replaced with another element) because it's easier
    // to do after the array of arrays has been flatted.
    let elements: some Sequence<Element> = result.lazy
      .flatMap { $0 }
      .map { (describe($0.value), $0.kind) as Element }
      .reduce(into: []) { result, element in
        if element.kind == .remove, let previous = result.last, previous.kind == .insert {
          result[result.index(before: result.endIndex)] = (previous.value, .replace(oldValue: element.value))
        } else {
          result.append(element)
        }
      }

    self.init(elements: elements)
  }

  /// Get a string reflecting a value, similar to how it might have been
  /// initialized and suitable for display as part of a difference.
  ///
  /// - Parameters:
  ///   - value: The value to reflect.
  ///
  /// - Returns: A string reflecting `value`, or `nil` if its reflection is
  ///   trivial.
  ///
  /// This function uses `Mirror`, so if the type of `value` conforms to
  /// `CustomReflectable`, the resulting string will be derived from the value's
  /// custom mirror.
  private static func _reflect<T>(_ value: T) -> String? {
    let mirror = Mirror(reflecting: value)
    let mirrorChildren = mirror.children
    if mirrorChildren.isEmpty {
      return nil
    }

    let typeName = _typeName(T.self, qualified: true)
    let separator = switch mirror.displayStyle {
    case .tuple, .collection, .set, .dictionary:
      ",\n"
    default:
      "\n"
    }
    let children = mirrorChildren.lazy
      .map { child in
        if let label = child.label {
          "  \(label): \(String(describingForTest: child.value))"
        } else {
          "  \(String(describingForTest: child.value))"
        }
      }.joined(separator: separator)

    switch mirror.displayStyle {
    case .tuple:
      return """
      (
      \(children)
      )
      """
    case .collection, .set, .dictionary:
      return """
      [
      \(children)
      ]
      """
    default:
      return """
      \(typeName)(
      \(children)
      )
      """
    }
  }

  /// Initialize an instance of this type by comparing the reflections of two
  /// values.
  ///
  /// - Parameters:
  ///   - lhs: The "old" value to compare.
  ///   - rhs: The "new" value to compare.
  init?<T, U>(comparingValue lhs: T, to rhs: U) {
    guard let lhsDump = Self._reflect(lhs), let rhsDump = Self._reflect(rhs) else {
      return nil
    }

    let lhsDumpLines = lhsDump.split(whereSeparator: \.isNewline)
    let rhsDumpLines = rhsDump.split(whereSeparator: \.isNewline)
    if lhsDumpLines.count > 1 || rhsDumpLines.count > 1 {
      self.init(from: lhsDumpLines, to: rhsDumpLines, describingForTest: false)
    } else {
      return nil
    }
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
