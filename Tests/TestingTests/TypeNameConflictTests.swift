//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing

@Suite("Type Name Conflict Tests")
struct TypeNameConflictTests {
  @Test("Test function does not conflict with local type names")
  func someTest() {
    #expect(Bool(true))
  }

  @Test("Test function does not conflict with local type names")
  @available(*, noasync)
  func someNoAsyncTest() {
    #expect(Bool(true))
  }
}

// MARK: - Fixtures

fileprivate struct SourceLocation {}
fileprivate struct __TestContentRecordContainer {}
fileprivate struct __XCTestCompatibleSelector {}

fileprivate func __forward<R>(_ value: R) async throws {
  Issue.record("Called wrong __forward()")
}
fileprivate func __forwardNoAsync<R>(_ value: @autoclosure () throws -> R) throws {
  Issue.record("Called wrong __forwardNoAsync()")
}

fileprivate func __invokeXCTestMethod<T>(
  _ selector: __XCTestCompatibleSelector?,
  onInstanceOf xcTestSubclass: T.Type,
  sourceLocation: SourceLocation
) {
  Issue.record("Called wrong __invokeXCTestMethod()")
}

fileprivate func __xcTestCompatibleSelector(_ selector: String) -> __XCTestCompatibleSelector? {
  Issue.record("Called wrong __xcTestCompatibleSelector()")
  return nil
}

@Suite(.hidden)
struct tests {
  @Test(.hidden)
  static func f() {}
}
