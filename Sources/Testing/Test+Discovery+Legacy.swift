//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A protocol describing a type that contains tests.
///
/// - Warning: This protocol is used to implement the `@Test` macro. Do not use
///   it directly.
@_alwaysEmitConformanceMetadata
public protocol __TestContainer {
  /// The set of tests contained by this type.
  static var __tests: [Test] { get async }
}

/// A string that appears within all auto-generated types conforming to the
/// `__TestContainer` protocol.
let testContainerTypeNameMagic = "__🟠$test_container__"

#if !SWT_NO_EXIT_TESTS
/// A protocol describing a type that contains an exit test.
///
/// - Warning: This protocol is used to implement the `#expect(exitsWith:)`
///   macro. Do not use it directly.
@_alwaysEmitConformanceMetadata
@_spi(Experimental)
public protocol __ExitTestContainer {
  /// The expected exit condition of the exit test.
  static var __expectedExitCondition: ExitCondition { get }

  /// The source location of the exit test.
  static var __sourceLocation: SourceLocation { get }

  /// The body function of the exit test.
  static var __body: @Sendable () async throws -> Void { get }
}

/// A string that appears within all auto-generated types conforming to the
/// `__ExitTestContainer` protocol.
let exitTestContainerTypeNameMagic = "__🟠$exit_test_body__"
#endif

// MARK: -

/// Get all types known to Swift found in the current process whose names
/// contain a given substring.
///
/// - Parameters:
///   - nameSubstring: A string which the names of matching classes all contain.
///
/// - Returns: A sequence of Swift types whose names contain `nameSubstring`.
func types(withNamesContaining nameSubstring: String) -> some Sequence<Any.Type> {
  SectionBounds.all(.typeMetadata).lazy.flatMap { sb in
    var count = 0
    let start = swt_copyTypes(in: sb.buffer.baseAddress!, sb.buffer.count, withNamesContaining: nameSubstring, count: &count)
    defer {
      free(start)
    }
    return UnsafeBufferPointer(start: start, count: count)
      .withMemoryRebound(to: Any.Type.self) { Array($0) }
  }
}
