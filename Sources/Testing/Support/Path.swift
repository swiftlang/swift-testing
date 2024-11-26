//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

/// A type representing a file system path.
///
/// This type is necessary because some file system paths do not contain valid
/// Unicode characters and so cannot be represented as instances of `String`.
///
/// This type is roughly equivalent to Foundation's [`URL`](https://developer.apple.com/documentation/foundation/url)
/// (when representing a file system path) or swift-system's [`FilePath`](https://developer.apple.com/documentation/system/filepath).
/// Because the testing library cannot add either of those modules as a direct
/// dependency, we have our own implementation.
///
/// This type is not part of the public interface of the testing library. When
/// exposing a path in the public interface, use `String` or another
/// contextually appropriate type.
struct Path: Sendable {
#if os(Windows)
  typealias Character = wchar_t
  typealias Encoding = UTF16
#else
  typealias Character = CChar
  typealias Encoding = UTF8
#endif

  /// The characters in this path's C string representation including its
  /// trailing null character.
  ///
  /// To get the value of this property, call ``withCString(_:)``.
  private var _cString: ContiguousArray<Character>

  /// Initialize an instance of this type with the given array of characters.
  ///
  /// - Parameters:
  ///   - characters: The characters in the path.
  ///
  /// If `characters` does not end with a null character (`0`), one is appended.
  /// Otherwise, the value of `characters` is not checked for correctness.
  init(_ characters: ContiguousArray<Character>) {
    _cString = characters
    if _cString.last != 0 {
      _cString.append(0)
    }
  }

  /// Initialize an instance of this type with the given C string.
  ///
  /// - Parameters:
  ///   - unsafeCString: The C string representing the path.
  ///
  /// The value of `unsafeCString` is not checked for correctness.
  init(unsafeCString: UnsafePointer<Character>) {
#if os(Windows)
    let buffer = UnsafeBufferPointer(start: unsafeCString, count: wcslen(unsafeCString) + 1)
#else
    let buffer = UnsafeBufferPointer(start: unsafeCString, count: strlen(unsafeCString) + 1)
#endif
    self.init(unsafeCharacters: buffer)
  }

  /// Initialize an instance of this type with the given character buffer.
  ///
  /// - Parameters:
  ///   - buffer: The buffer representing the path.
  ///
  /// If `buffer` does not end with a null character (`0`), one is appended.
  /// Otherwise, the value of `buffer` is not checked for correctness.
  init(unsafeCharacters buffer: UnsafeBufferPointer<Character>) {
    self.init(ContiguousArray(buffer))
  }

  /// Get this instance's underlying C string suitable for use with
  /// platform-specific interfaces.
  ///
  /// - Parameters:
  ///   - body: A function to invoke. A C string is passed to this function.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  func withCString<R>(_ body: (UnsafePointer<Character>) throws -> R) rethrows -> R {
    try _cString.withUnsafeBufferPointer { buffer in
      try body(buffer.baseAddress!)
    }
  }

  /// The number of characters in this path.
  ///
  /// The value of this property represents the number of UTF-8 code points
  /// (UTF-16 code points on Windows) in this path, not including any trailing
  /// null character.
  var count: Int {
    _cString.count
  }
}

// MARK: - Single path component

extension Path {
  struct Component: Sendable {
    typealias Character = Path.Character
    typealias Encoding = Path.Encoding

#if os(Windows)
    /// The set of supported path separator characters.
    static let separatorCharacters = [Character(UInt8(ascii: #"\"#)), Character(UInt8(ascii: "/"))]
#else
    /// The path separator character.
    static let separatorCharacter = Character(bitPattern: UInt8(ascii: "/"))
#endif

    /// A type describing storage for `Path.Component`.
    private enum _Storage {
      /// The path component is stored as a subsequence of a contiguous array of
      /// path characters.
      ///
      /// This case is used when a component is constructed from a path in order
      /// to avoid copying.
      case slice(ContiguousArray<Character>.SubSequence)

      /// The path component is a string or string literal and is stored as an
      /// instance of `String`.
      case string(String)
    }

    private var _storage: _Storage

    fileprivate init(_ characters: ContiguousArray<Character>.SubSequence) {
      _storage = .slice(characters)
    }

    /// Get this instance's underlying character buffer.
    ///
    /// - Parameters:
    ///   - body: A function to invoke. A buffer pointer is passed to this
    ///     function; the value of this buffer pointer's `count` property does not
    ///     include the trailing null character.
    ///
    /// - Returns: Whatever is returned by `body`.
    ///
    /// - Throws: Whatever is thrown by `body`.
    func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Character>) throws -> R) rethrows -> R {
      switch _storage {
      case let .slice(characters):
        return try characters.withUnsafeBufferPointer { characters in
          try body(characters)
        }
      case let .string(stringValue):
#if os(Windows)
        return try stringValue.withCString(encodedAs: UTF16.self) { cString in
          let count = wcslen(cString)
          let buffer = UnsafeBufferPointer(start: cString, count: count)
          return try body(buffer)
        }
#else
        var stringValue = stringValue
        return try stringValue.withUTF8 { buffer in
          try buffer.withMemoryRebound(to: Character.self) { buffer in
            try body(buffer)
          }
        }
#endif
      }
    }

    /// _Does_ include a trailing `0`, but makes a copy.
    fileprivate var cString: ContiguousArray<Character> {
      withUnsafeBufferPointer { buffer in
        var result = ContiguousArray(buffer)
        result.append(0)
        return result
      }
    }
  }
}

// MARK: - String conversion

extension Path: ExpressibleByStringLiteral, CustomStringConvertible {
  init(stringLiteral: String) {
    self.init(stringLiteral)
  }

  init(_ stringValue: String) {
#if os(Windows)
    _cString = stringValue.withCString(encodedAs: UTF16.self) { cString in
        let count = wcslen(cString)
        let buffer = UnsafeBufferPointer(start: cString, count: count + 1)
        return ContiguousArray(buffer)
    }
#else
    _cString = stringValue.utf8CString
#endif
  }

  /// A description of this path suitable for display.
  ///
  /// The value of this property is _not_ suitable for use programmatically as
  /// the underlying buffer may not contain valid Unicode and this property
  /// may not accurately represent it.
  var description: String {
    _cString.withUnsafeBufferPointer { buffer in
      buffer.withMemoryRebound(to: Encoding.CodeUnit.self) { buffer in
        String.decodeCString(buffer.baseAddress!, as: Encoding.self, repairingInvalidCodeUnits: true)?.result ?? "\u{FFFD}"
      }
    }
  }
}

extension Path.Component: ExpressibleByStringLiteral, CustomStringConvertible {
  init(stringLiteral: String) {
    self.init(stringLiteral)
  }

  init(_ stringValue: String) {
#if !os(Windows)
    var stringValue = stringValue
    stringValue.makeContiguousUTF8()
#endif
    _storage = .string(stringValue)
  }

  /// A description of this path suitable for display.
  ///
  /// The value of this property is _not_ suitable for use programmatically as
  /// the underlying buffer may not contain valid Unicode and this property
  /// may not accurately represent it.
  var description: String {
    cString.withUnsafeBufferPointer { buffer in
      buffer.withMemoryRebound(to: Encoding.CodeUnit.self) { buffer in
        String.decodeCString(buffer.baseAddress!, as: Encoding.self, repairingInvalidCodeUnits: true)?.result ?? "\u{FFFD}"
      }
    }
  }
}

// MARK: - Equatable, Hashable

extension Path: Equatable, Hashable {}

extension Path.Component: Equatable, Hashable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.withUnsafeBufferPointer { lhs in
      rhs.withUnsafeBufferPointer { rhs in
        lhs.elementsEqual(rhs)
      }
    }
  }

  func hash(into hasher: inout Hasher) {
    withUnsafeBufferPointer { buffer in
      for c in buffer {
        hasher.combine(c)
      }
    }
  }
}

// MARK: - Appending

extension Path {
  mutating func append(_ pathComponent: Component) {
#if os(Windows)
    self = withCString { path in
      pathComponent.cString.withUnsafeBufferPointer { pathComponent in
        var result: UnsafeMutablePointer<wchar_t>?
        let rCombine = PathAllocCombine(
          path,
          pathComponent.baseAddress!,
          ULONG(PATHCCH_ALLOW_LONG_PATHS.rawValue | PATHCCH_DO_NOT_NORMALIZE_SEGMENTS.rawValue),
          &result
        )
        guard S_OK == rCombine, let result else {
          fatalError("Failed to concatenate \(self) and \(pathComponent): H_RESULT(\(rCombine)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
        }
        defer {
          LocalFree(result)
        }
        return Self(unsafeCString: result)
      }
    }
#else
    pathComponent.withUnsafeBufferPointer { pathComponent in
      guard pathComponent.count > 0 else {
        return
      }

      _cString.removeLast() // remove trailing null character
      if !_cString.isEmpty && _cString.last != Component.separatorCharacter {
        _cString.append(Component.separatorCharacter)
      }
      _cString += pathComponent
      _cString.append(0)
    }
#endif
  }

  func appending(_ pathComponent: Component) -> Self {
    var result = self
    result.append(pathComponent)
    return result
  }
}

// MARK: - Last path component

extension Path {
  private var _rangeOfLastComponent: Range<ContiguousArray<Character>.Index>? {
    var result = _cString[...].dropLast() // remove trailing null character

    // Trim any trailing slashes.
#if os(Windows)
    while let lastCharacter = result.last, Component.separatorCharacters.contains(lastCharacter) {
      result = result.dropLast()
    }
#else
    while result.last == Component.separatorCharacter {
      result = result.dropLast()
    }
#endif

    // Find the last slash character (we've already trimmed any trailing ones.)
    // Everything after that slash is part of the last path component. If there
    // is no last slash, the entire (relative) path is the last component.
#if os(Windows)
    let slashIndex = result.lastIndex(where: Component.separatorCharacters.contains)
#else
    let slashIndex = result.lastIndex(of: Component.separatorCharacter)
#endif
    let range = if let slashIndex, slashIndex > result.startIndex {
      result.index(after: slashIndex) ..< result.endIndex
    } else {
      result.startIndex ..< result.endIndex
    }

    if range.isEmpty {
      return nil
    }
    return range
  }

  var lastComponent: Component? {
    _rangeOfLastComponent.flatMap { range in
      if range.isEmpty {
        return nil
      }
      return Component(_cString[range])
    }
  }

  mutating func removeLastComponent() {
    guard let range = _rangeOfLastComponent else {
      return
    }

    _cString.removeSubrange(range.lowerBound ..< _cString.endIndex)
    _cString.append(0)
  }

  func removingLastComponent() -> Self {
    var result = self
    result.removeLastComponent()
    return result
  }
}

// MARK: - File system properties

extension Path {
  /// Check if a file exists at this path.
  ///
  /// - Returns: Whether or not a file exists at this path on disk.
  ///
  /// - Throws: If an error occurred while checking if a file exists. `ENOENT`
  ///   (`ERROR_FILE_NOT_FOUND` on Windows) is not thrown.
  var exists: Bool {
    get throws {
      try withCString { path in
#if os(Windows)
        let result = PathFileExistsW(path)
        if !result {
          let errorCode = GetLastError()
          if errorCode != ERROR_FILE_NOT_FOUND {
            throw Win32Error(rawValue: errorCode)
          }
        }
#else
        let result = (0 == access(path, F_OK))
        if !result {
          let errorCode = swt_errno()
          if errorCode != ENOENT {
            throw CError(rawValue: errorCode)
          }
        }
#endif
        return result
      }
    }
  }

  /// Resolve a relative path or a path containing symbolic links to a canonical
  /// absolute path.
  ///
  /// - Throws: Any error preventing path resolution.
  ///
  /// On return, this instance refers to a fully resolved copy of its original
  /// path value. If the path is already fully resolved, the resulting path may
  /// differ slightly but refers to the same file system object.
  mutating func resolve() throws {
#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD) || os(Android) || os(WASI)
    self = try withCString { path in
      guard let resolvedCPath = realpath(path, nil) else {
        throw CError(rawValue: swt_errno())
      }
      defer {
        free(resolvedCPath)
      }
      return Self(unsafeCString: resolvedCPath)
    }
#elseif os(Windows)
    self = try withCString { path in
      guard let resolvedCPath = _wfullpath(nil, path, 0) else {
        throw CError(rawValue: swt_errno())
      }
      defer {
        free(resolvedCPath)
      }
      return Self(unsafeCString: resolvedCPath)
    }
#else
#warning("Platform-specific implementation missing: cannot resolve paths")
    return nil
#endif
  }

  /// Resolve a relative path or a path containing symbolic links to a canonical
  /// absolute path.
  ///
  /// - Returns: A fully resolved copy of this path. If the path is already
  ///   fully resolved, the resulting path may differ slightly but refers to the
  ///   same file system object.
  ///
  /// - Throws: Any error preventing path resolution.
  func resolved() throws -> Self {
    var result = self
    try result.resolve()
    return result
  }
}

// MARK: - General path utilities (to move into `Path`)

/// Append a path component to a path.
///
/// - Parameters:
///   - pathComponent: The path component to append.
///   - path: The path to which `pathComponent` should be appended.
///
/// - Returns: The full path to `pathComponent`, or `nil` if the resulting
///   string could not be created.
@available(*, deprecated, message: "Use Path.append(_:) instead.")
func appendPathComponent(_ pathComponent: String, to path: String) -> String {
  var path = Path(path)
  path.append(Path.Component(pathComponent))
  return String(describing: path)
}

/// Check if a file exists at a given path.
///
/// - Parameters:
///   - path: The path to check.
///
/// - Returns: Whether or not the path `path` exists on disk.
@available(*, deprecated, message: "Use Path.exists instead.")
func fileExists(atPath path: String) -> Bool {
  (try? Path(path).exists) ?? false
}

/// Resolve a relative path or a path containing symbolic links to a canonical
/// absolute path.
///
/// - Parameters:
///   - path: The path to resolve.
///
/// - Returns: A fully resolved copy of `path`. If `path` is already fully
///   resolved, the resulting string may differ slightly but refers to the same
///   file system object. If the path could not be resolved, returns `nil`.
func canonicalizePath(_ path: String) -> String? {
  if let path = try? Path(path).resolved() {
    return String(describing: path)
  }
  return nil
}
