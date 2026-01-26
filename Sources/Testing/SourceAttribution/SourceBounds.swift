//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing a range of source locations in source code.
///
/// This type is not part of the public interface of the testing library.
public struct __SourceBounds: Sendable {
  /// The lower bound of this range.
  ///
  /// The range includes this source location.
  @_spi(Experimental)
  public fileprivate(set) var lowerBound: SourceLocation

  /// Storage for ``upperBound``.
  private var _upperBound: (line: Int, column: Int)

  /// The upper bound of this range.
  ///
  /// The range does _not_ include this source location.
  @_spi(Experimental)
  public var upperBound: SourceLocation {
    SourceLocation(
      fileID: lowerBound.fileID,
      filePath: lowerBound.filePath,
      line: _upperBound.line,
      column: _upperBound.column
    )
  }
}

// MARK: -

@_spi(Experimental)
extension __SourceBounds {
  public init(lowerBound: SourceLocation, upperBound: SourceLocation) {
#if DEBUG
    precondition(lowerBound.fileID == upperBound.fileID, "Cannot construct an instance of '__SourceBounds' across two different file IDs")
    precondition(lowerBound.filePath == upperBound.filePath, "Cannot construct an instance of '__SourceBounds' across two different file paths")
    precondition(lowerBound.line <= upperBound.line, "Cannot construct an instance of '__SourceBounds' whose upper bound comes before its lower bound")
    if lowerBound.line == upperBound.line {
      precondition(lowerBound.column < upperBound.column, "Cannot construct an instance of '__SourceBounds' whose upper bound comes before its lower bound")
    }
#endif

    self.init(lowerBound: lowerBound, _upperBound: (upperBound.line, upperBound.column))
  }

  init(lowerBoundOnly lowerBound: SourceLocation) {
    self.init(lowerBound: lowerBound, _upperBound: (lowerBound.line, lowerBound.column + 1))
  }
}

// MARK: - RangeExpression

@_spi(Experimental)
extension __SourceBounds: RangeExpression {
  public func relative<C>(to collection: C) -> Range<SourceLocation> where C : Collection, SourceLocation == C.Index {
    // I'm honestly not sure how I'm supposed to implement this function, but
    // this matches what Range<T> does (and both Range<T> and this type
    // represent half-open ranges, so it must be right, right?)
    lowerBound ..< upperBound
  }
  
  public func contains(_ element: SourceLocation) -> Bool {
    // This function can also be implemented more simply as:
    //
    // ```swift
    // lowerBound <= element && element < _upperBound
    // ```
    //
    // However that implementation produces extra redundant string comparisons.
    if element.line == lowerBound.line {
      guard element.column >= lowerBound.column else {
        // `element` is earlier on the same line as `lowerBound`.
        return false
      }
    }
    if element.line == _upperBound.line {
      guard element.column < _upperBound.column else {
        // `element` is later on the same line as `_upperBound`.
        return false
      }
    }
    if element.line >= lowerBound.line && element.line < _upperBound.line,
       element.fileID == lowerBound.fileID && element.filePath == lowerBound.filePath {
      return true
    }
    return false
  }
}

// MARK: - Macro support

extension __SourceBounds {
  /// - Warning: This initializer is used to implement the `@Test` macro. Do not
  ///   call it directly.
  public init(__uncheckedLowerBound lowerBound: SourceLocation, upperBound: (line: Int, column: Int)) {
    self.init(lowerBound: lowerBound, _upperBound: upperBound)
  }
}
