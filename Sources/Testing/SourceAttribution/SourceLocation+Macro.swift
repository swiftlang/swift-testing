//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// Get the current source location.
///
/// - Returns: This expression's location in the current Swift source file.
///
/// At compile time, the testing library expands this macro to an instance of
/// ``SourceLocation`` referring to the location of the macro invocation itself.
/// If you want to create an instance of ``SourceLocation`` from specific file
/// ID, file path, line, and column values, use ``SourceLocation/init(fileID:filePath:line:column:)``
/// instead.
///
/// You can use this expression macro in place of [`#fileID`](https://developer.apple.com/documentation/swift/fileid()),
/// [`#filePath`](https://developer.apple.com/documentation/swift/filepath()),
/// [`#line`](https://developer.apple.com/documentation/swift/line()), and
/// [`#column`](https://developer.apple.com/documentation/swift/column()) as a
/// default argument to a function.
///
/// ```swift
/// func cookBurger(sourceLocation: SourceLocation = #_sourceLocation) {
///   // ...
/// }
/// ```
@freestanding(expression) public macro _sourceLocation() -> SourceLocation = #externalMacro(module: "TestingMacros", type: "SourceLocationMacro")

/// Get the current source location.
///
/// - Returns: This expression's location in the current Swift source file.
///
/// At compile time, the testing library expands this macro to an instance of
/// ``SourceLocation`` referring to the location of the macro invocation itself.
/// If you want to create an instance of ``SourceLocation`` from specific file
/// ID, file path, line, and column values, use ``SourceLocation/init(fileID:filePath:line:column:)``
/// instead.
///
/// - Important: You must specify a module selector when you use this expression
///   macro to avoid conflicting with the Swift compiler's [`#sourceLocation(file:line:)`](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/#Line-Control-Statement)
///   statement.
///
///   ```swift
///   let here = #Testing::sourceLocation
///   ```
///
/// You can use this expression macro in place of [`#fileID`](https://developer.apple.com/documentation/swift/fileid()),
/// [`#filePath`](https://developer.apple.com/documentation/swift/filepath()),
/// [`#line`](https://developer.apple.com/documentation/swift/line()), and
/// [`#column`](https://developer.apple.com/documentation/swift/column()) as a
/// default argument to a function.
///
/// ```swift
/// func cookBurger(sourceLocation: SourceLocation = #Testing::sourceLocation) {
///   // ...
/// }
/// ```
@_spi(Experimental)
@freestanding(expression) public macro sourceLocation() -> SourceLocation = #externalMacro(module: "TestingMacros", type: "SourceLocationMacro")

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
    Self(__uncheckedFileID: fileID, filePath: filePath, line: line, column: column)
  }

  /// Initialize an instance of this type without validating any arguments.
  ///
  /// - Warning: This initializer is used to implement the `#_sourceLocation`
  ///   macro. Do not call it directly.
  public init(__uncheckedFileID fileID: String, filePath: String, line: Int, column: Int) {
    self.fileID = fileID
    self.filePath = filePath
    self.line = line
    self.column = column
  }
}
