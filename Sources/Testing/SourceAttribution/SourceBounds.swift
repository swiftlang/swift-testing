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
  ///
  /// - Note: If we ever need to save a word in this structure, we can probably
  ///   narrow the fields of this tuple to `Int32` without affecting any
  ///   real-world use cases.
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
    return lowerBound <= element && element < upperBound

    // The trivial implementation compares fileID and filePath twice. We can
    // avoid those comparisons with the algorithm below if needed (and if the
    // compiler is unable to optimize away the extra comparisons):
#if false
    if element.line == lowerBound.line && element.column < lowerBound.column {
      // `element` is earlier on the same line as `lowerBound`.
      return false
    }
    if element.line == _upperBound.line && element.column >= _upperBound.column {
      // `element` is later on the same line as `_upperBound`.
      return false
    }
    if element.line >= lowerBound.line && element.line < _upperBound.line,
       element.fileID == lowerBound.fileID && element.filePath == lowerBound.filePath {
      return true
    }
    return false
#endif
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
