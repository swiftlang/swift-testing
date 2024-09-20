//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension CollectionDifference<Any> {
  /// Convert an instance of `CollectionDifference` to one that is type-erased
  /// over elements of type `Any`.
  ///
  /// - Parameters:
  ///   - difference: The difference to convert.
  init(_ difference: CollectionDifference<some Any>) {
    self.init(
      difference.lazy.map { change in
        switch change {
        case let .insert(offset, element, associatedWith):
          return .insert(offset: offset, element: element as Any, associatedWith: associatedWith)
        case let .remove(offset, element, associatedWith):
          return .remove(offset: offset, element: element as Any, associatedWith: associatedWith)
        }
      }
    )!
  }
}

// MARK: -

extension CollectionDifference.Change {
  /// The element that was changed.
  var element: ChangeElement {
    switch self {
    case let .insert(offset: _, element: result, associatedWith: _), let .remove(offset: _, element: result, associatedWith: _):
      return result
    }
  }
}
