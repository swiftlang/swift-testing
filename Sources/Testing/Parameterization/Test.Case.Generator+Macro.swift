//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

//public struct S: Sendable where S: Sendable & Sequence {
//  private var _sequence: S
//
//  private var _describe: @Sendable (any Sendable) -> String
//
//  func describe<V>(_ argumentValue: V) -> String where V: Sendable {
//    _describe(argumentValue)
//  }
//
//  @_disfavoredOverload
//  public init(_ sequence: S) {
//    _sequence = sequence
//    _describe = { String(describingForTest: $0) }
//  }
//
//  public init(_ sequence: S) where S.Element: CustomTestStringConvertible {
//    _sequence = sequence
//    func describe(_ value: some Sendable & CustomTestStringConvertible) -> String {
//      String(describingForTest: value)
//    }
//    _describe = { describe($0) }
//  }
//}
//
//func makeArguments<S>(_ arguments: S) -> S {
//  __Arguments(arguments)
//}
//
//func makeArguments<S>(_ arguments: S) -> S where S.Element: CustomTestStringConvertible {
//  __Arguments(arguments)
//}
//
//// MARK: - Sequence
//
//extension __Arguments: Sequence {
//  public func makeIterator() -> S.Iterator {
//    _sequence.makeIterator()
//  }
//
//  public var underestimatedCount: Int {
//    _sequence.underestimatedCount
//  }
//}
//
//// MARK: - Collection
//
//extension __Arguments: Collection where S: Collection {
//  public var startIndex: S.Index {
//    _sequence.startIndex
//  }
//
//  public var endIndex: S.Index {
//    _sequence.endIndex
//  }
//
//  public subscript(position: S.Index) -> S.Element {
//    _read {
//      yield _sequence[position]
//    }
//  }
//
//  public subscript(bounds: Range<S.Index>) -> S.SubSequence {
//    _read {
//      yield _sequence[bounds]
//    }
//  }
//
//  public var indices: S.Indices {
//    _sequence.indices
//  }
//
//  public var isEmpty: Bool {
//    _sequence.isEmpty
//  }
//
//  public var count: Int {
//    _sequence.count
//  }
//
//  public func index(_ i: S.Index, offsetBy distance: Int) -> S.Index {
//    _sequence.index(i, offsetBy: distance)
//  }
//
//  public func index(_ i: S.Index, offsetBy distance: Int, limitedBy limit: S.Index) -> S.Index? {
//    _sequence.index(i, offsetBy: distance, limitedBy: limit)
//  }
//
//  public func distance(from start: S.Index, to end: S.Index) -> Int {
//    _sequence.distance(from: start, to: end)
//  }
//
//  public func index(after i: S.Index) -> S.Index {
//    _sequence.index(after: i)
//  }
//
//  public func formIndex(after i: inout S.Index) {
//    _sequence.formIndex(after: &i)
//  }
//}
