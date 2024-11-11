//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing a location in source code.
public struct SourceLocation: Sendable {
  /// The file ID of the source file.
  ///
  /// - Precondition: The value of this property must not be empty and must be
  ///   formatted as described in the documentation for the
  ///   [`#fileID`](https://developer.apple.com/documentation/swift/fileID()).
  ///   macro in the Swift standard library.
  ///
  /// ## See Also
  ///
  /// - ``moduleName``
  /// - ``fileName``
  public var fileID: String {
    willSet {
      precondition(!newValue.isEmpty, "SourceLocation.fileID must not be empty (was \(newValue))")
      precondition(newValue.contains("/"), "SourceLocation.fileID must be a well-formed file ID (was \(newValue))")
    }
  }

  /// The name of the source file.
  ///
  /// The name of the source file is derived from this instance's ``fileID``
  /// property. It consists of the substring of the file ID after the last
  /// forward-slash character (`"/"`.) For example, if the value of this
  /// instance's ``fileID`` property is `"FoodTruck/WheelTests.swift"`, the
  /// file name is `"WheelTests.swift"`.
  ///
  /// The structure of file IDs is described in the documentation for
  /// [`#fileID`](https://developer.apple.com/documentation/swift/fileID())
  /// in the Swift standard library.
  ///
  /// ## See Also
  ///
  /// - ``fileID``
  /// - ``moduleName``
  public var fileName: String {
    let lastSlash = fileID.lastIndex(of: "/")!
    return String(fileID[fileID.index(after: lastSlash)...])
  }

  /// The name of the module containing the source file.
  ///
  /// The name of the module is derived from this instance's ``fileID``
  /// property. It consists of the substring of the file ID up to the first
  /// forward-slash character (`"/"`.) For example, if the value of this
  /// instance's ``fileID`` property is `"FoodTruck/WheelTests.swift"`, the
  /// module name is `"FoodTruck"`.
  ///
  /// The structure of file IDs is described in the documentation for the
  /// [`#fileID`](https://developer.apple.com/documentation/swift/fileID())
  /// macro in the Swift standard library.
  ///
  /// ## See Also
  ///
  /// - ``fileID``
  /// - ``fileName``
  /// - [`#fileID`](https://developer.apple.com/documentation/swift/fileID())
  public var moduleName: String {
    let firstSlash = fileID.firstIndex(of: "/")!
    return String(fileID[..<firstSlash])
  }

  /// The path to the source file.
  ///
  /// - Warning: This property is provided temporarily to aid in integrating the
  ///   testing library with existing tools such as Swift Package Manager. It
  ///   will be removed in a future release.
  public var _filePath: String

  /// The line in the source file.
  ///
  /// - Precondition: The value of this property must be greater than `0`.
  public var line: Int {
    willSet {
      precondition(newValue > 0, "SourceLocation.line must be greater than 0 (was \(newValue))")
    }
  }

  /// The column in the source file.
  ///
  /// - Precondition: The value of this property must be greater than `0`.
  public var column: Int {
    willSet {
      precondition(newValue > 0, "SourceLocation.column must be greater than 0 (was \(newValue))")
    }
  }

  /// Initialize an instance of this type with the specified location details.
  ///
  /// - Parameters:
  ///   - fileID: The file ID of the source file, using the format described in
  ///     the documentation for the
  ///     [`#fileID`](https://developer.apple.com/documentation/swift/fileID())
  ///     macro in the Swift standard library.
  ///   - filePath: The path to the source file.
  ///   - line: The line in the source file. Must be greater than `0`.
  ///   - column: The column in the source file. Must be greater than `0`.
  ///
  /// - Precondition: `fileID` must not be empty and must be formatted as
  ///   described in the documentation for
  ///   [`#fileID`](https://developer.apple.com/documentation/swift/fileID()).
  /// - Precondition: `line` must be greater than `0`.
  /// - Precondition: `column` must be greater than `0`.
  public init(fileID: String, filePath: String, line: Int, column: Int) {
    precondition(!fileID.isEmpty, "SourceLocation.fileID must not be empty (was \(fileID))")
    precondition(fileID.contains("/"), "SourceLocation.fileID must be a well-formed file ID (was \(fileID))")
    precondition(line > 0, "SourceLocation.line must be greater than 0 (was \(line))")
    precondition(column > 0, "SourceLocation.column must be greater than 0 (was \(column))")

    self.fileID = fileID
    self._filePath = filePath
    self.line = line
    self.column = column
  }
}

// MARK: - Equatable, Hashable, Comparable

extension SourceLocation: Equatable, Hashable, Comparable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.line == rhs.line && lhs.column == rhs.column && lhs.fileID == rhs.fileID
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(fileID)
    hasher.combine(line)
    hasher.combine(column)
  }

  public static func <(lhs: Self, rhs: Self) -> Bool {
    // Tests are sorted in the order in which they appear in source, with file
    // IDs sorted alphabetically in the neutral locale.
    if lhs.fileID < rhs.fileID {
      return true
    } else if lhs.fileID == rhs.fileID {
      if lhs.line < rhs.line {
        return true
      } else if lhs.line == rhs.line {
        return lhs.column < rhs.column
      }
    }
    return false
  }
}

// MARK: - CustomStringConvertible, CustomDebugStringConvertible

extension SourceLocation: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    return "\(fileName):\(line):\(column)"
  }

  public var debugDescription: String {
    return "\(fileID):\(line):\(column)"
  }
}

// MARK: - Codable

extension SourceLocation: Codable {}
