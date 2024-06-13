//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// Get the current source location as a compile-time constant.
///
/// - Returns: The source location at which this macro is applied.
///
/// This macro can be used in place of `#fileID`, `#line`, and `#column` as a
/// default argument to a function. It expands to an instance of
/// ``SourceLocation`` referring to the location of the macro invocation itself
/// (similar to how `#fileID` expands to the ID of the file containing the
/// `#fileID` invocation.)
@freestanding(expression) public macro _sourceLocation() -> SourceLocation = #externalMacro(module: "TestingMacros", type: "SourceLocationMacro")

extension SourceLocation {
  /// Get the current source location as an instance of ``SourceLocation``.
  ///
  /// - Warning: This function is used to implement the `#_sourceLocation`
  ///   macro. Do not call it directly.
  public static func __here(
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column
  ) -> Self {
    Self(fileID: fileID, filePath: filePath, line: line, column: column)
  }
}
