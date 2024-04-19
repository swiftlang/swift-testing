//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
private import TestingInternals

@Suite("Issue tests")
struct IssueTests {
  struct BasicExpectationArguments: Sendable, CustomTestStringConvertible {
    var name: String
    var isPassing = false
    var isKnown = false
    var isRequired = false
    var isThrownError = false
    var testFunction: @Sendable () async throws -> Void

    var testDescription: String {
      name
    }
  }

  static let basicExpectationArguments: [BasicExpectationArguments] = [
    .init(name: "#expect()") {
      #expect(Bool(true))
      #expect(Bool(false))
      #expect(Bool(false), "Custom message")
    },
    .init(name: "#require()", isRequired: true) {
      try #require(Bool(true))
      try #require(Bool(false), "Custom message")
      Issue.record("Unreachable")
    },
    .init(name: "unwrapping optionals with #require()", isRequired: true) {
      let x: Int? = 1
      #expect(try 1 == #require(x))
      let y: String? = nil
      _ = try #require(y)
      Issue.record("Unreachable")
    },
    .init(name: "unwrapping ?? with #require() (passing)", isPassing: true, isRequired: true) {
      let x: String? = nil
      _ = try #require(x ?? "hello")
    },
    .init(name: "unwrapping ?? with #require() (failing)", isPassing: false, isRequired: true) {
      let x: String? = nil
      let y: String? = nil
      _ = try #require(x ?? y)
      Issue.record("Unreachable")
    },
    .init(name: "#expect() throwing error", isThrownError: true) { () throws in
      #expect(try { throw MyError() }())
    },
    .init(name: "#expect() throwing error (external try)", isThrownError: true) {
      try #expect({ throw MyError() }())
    }
  ]

  @Test("Basic expectations", arguments: basicExpectationArguments)
  func expect(arguments: BasicExpectationArguments) async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if arguments.isPassing {
        Issue.record("Unexpected issue \(issue)")
      } else {
        #expect(arguments.isKnown == issue.isKnown)
        if arguments.isThrownError {
          guard case let .errorCaught(error) = issue.kind else {
            Issue.record("Unexpected issue kind \(issue.kind)")
            return
          }
          #expect(error is MyError)
        } else {
          guard case let .expectationFailed(expectation) = issue.kind else {
            Issue.record("Unexpected issue kind \(issue.kind)")
            return
          }
          #expect(arguments.isRequired == expectation.isRequired)
        }
      }
    }

    await Test {
      try await arguments.testFunction()
    }.run(configuration: configuration)
  }

  struct MemberFunctionCallTestArguments: Sendable, CustomTestStringConvertible {
    var name: String
    var contains = [String]()
    var doesNotContain = [String]()
    var hasEvaluatedExpression = false
    var expectedConfirmationCount = 1
    var testFunction: @Sendable () async throws -> Void

    var testDescription: String {
      String(describingForTest: name)
    }
  }

  static let memberFunctionCallArguments: [MemberFunctionCallTestArguments] = [
    .init(name: "unlabelled argument", contains: ["rhs → 1"], doesNotContain: ["(("]) {
      let rhs = 1
      #expect(TypeWithMemberFunctions.f(rhs))
    },
    .init(name: "labelled argument", contains: ["label: rhs → 1"], doesNotContain: ["(("]) {
      let rhs = 1
      #expect(TypeWithMemberFunctions.g(label: rhs))
    },
    .init(name: "function as argument", doesNotContain: ["(Function)", "(("]) {
      #expect(TypeWithMemberFunctions.h({ }))
    },
    .init(name: "unwrapping optional", hasEvaluatedExpression: true) {
      // The evaluated expression here is `.some(.none)`
      _ = try #require(TypeWithMemberFunctions.j(1))
    },
    .init(name: "inout argument", expectedConfirmationCount: 2) {
      var i = 0
      #expect(TypeWithMemberFunctions.k(&i))
      #expect(TypeWithMemberFunctions.m(TypeWithMemberFunctions.k(&i)))
    },
    .init(name: "throwing", expectedConfirmationCount: 2) { () throws in
      // The presence of `try` means we don't do complex expansion (yet.)
      #expect(try TypeWithMemberFunctions.n(0))
      #expect(TypeWithMemberFunctions.f(try { () throws in 0 }()))
    },
  ]

  @Test("#expect() with a member function call", arguments: memberFunctionCallArguments)
  func memberFunctionCall(arguments: MemberFunctionCallTestArguments) async throws {
    await confirmation("Expectation failed", expectedCount: arguments.expectedConfirmationCount) { expectationFailed in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        guard case let .issueRecorded(issue) = event.kind else {
          return
        }
        if case let .expectationFailed(expectation) = issue.kind {
          expectationFailed()
          let desc = expectation.evaluatedExpression.expandedDescription()
          for containee in arguments.contains {
            #expect(desc.contains(containee))
          }
          for nonContainee in arguments.doesNotContain {
            #expect(!desc.contains(nonContainee))
          }
          if arguments.hasEvaluatedExpression {
            #expect(expectation.evaluatedExpression.runtimeValue != nil)
          } else {
            #expect(expectation.evaluatedExpression.runtimeValue == nil)
          }
        }
      }

      await Test {
        try await arguments.testFunction()
      }.run(configuration: configuration)
    }
  }

  @Test("Lazy stringification of captured expectation value")
  func expectationValueLazyStringification() async {
    struct Delicate: Equatable, CustomStringConvertible {
      var description: String {
        Issue.record("Should not be called")
        return "danger"
      }
    }

    await confirmation("expectation checked") { expectationChecked in
      var configuration = Configuration()
      configuration.deliverExpectationCheckedEvents = true
      configuration.eventHandler = { event, _ in
        guard case let .expectationChecked(expectation) = event.kind else {
          return
        }
        #expect(expectation.evaluatedExpression.subexpressions[0].runtimeValue == nil)
        expectationChecked()
      }

      await Test {
        #expect(Delicate() == Delicate())
      }.run(configuration: configuration)
    }
  }

  @Test("Literal expressions captured in expectations")
  func testExpressionLiterals() async {
    func expectIssue(containing content: String, in testFunction: @escaping @Sendable () async throws -> Void) async {
      await confirmation("Issue recorded") { issueRecorded in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          guard case let .issueRecorded(issue) = event.kind,
                case let .expectationFailed(expectation) = issue.kind else {
            return
          }
          #expect(issue.comments.isEmpty)
          let expandedExpressionDescription = expectation.evaluatedExpression.expandedDescription()
          #expect(expandedExpressionDescription.contains(content))
          issueRecorded()
        }

        await Test(testFunction: testFunction).run(configuration: configuration)
      }
    }

    @Sendable func someInt() -> Int { 0 }
    @Sendable func someString() -> String { "a" }

    await expectIssue(containing: "(someInt() → 0) == 1") {
      #expect(someInt() == 1)
    }
    await expectIssue(containing: "1 == (someInt() → 0)") {
      #expect(1 == someInt())
    }
    await expectIssue(containing: "(someString() → \"a\") == \"b\"") {
      #expect(someString() == "b")
    }
  }

  struct RuntimeValueCaptureArguments: Sendable, CustomTestStringConvertible {
    var value: any Sendable
    var moreChecks: @Sendable (Expression.Value) throws -> Void = { _ in }
    var testDescription: String {
      String(describingForTest: value)
    }
  }

  static let runtimeValueCaptureArguments: [RuntimeValueCaptureArguments] = [
    .init(value: 987 as Int) { runtimeValue in
      #expect(runtimeValue.children == nil)
      #expect(runtimeValue.label == nil)
    },
    .init(value: ExpressionRuntimeValueCapture_Value()),
    .init(value: (123, "abc") as (Int, String)),
    .init(value: ExpressionRuntimeValueCapture_ValueWithChildren(contents: [123, "abc"])) { runtimeValue in
      #expect(runtimeValue.label == nil)

      let children = try #require(runtimeValue.children)
      #expect(children.count == 1)
      let contentsArrayChild = try #require(children.first)
      #expect(String(describing: contentsArrayChild) == #"[123, "abc"]"#)
      #expect(contentsArrayChild.isCollection)
      #expect(contentsArrayChild.label == "contents")

      let contentsChildren = try #require(contentsArrayChild.children)
      #expect(contentsChildren.count == 2)
      let firstContentsElementChild = try #require(contentsChildren.first)
      #expect(String(describing: firstContentsElementChild) == "123")
      #expect(!firstContentsElementChild.isCollection)
      #expect(firstContentsElementChild.label == nil)
    },
    .init(value: [any Sendable]()) { runtimeValue in
      #expect(runtimeValue.label == nil)
      let children = try #require(runtimeValue.children)
      #expect(children.isEmpty)
    }
  ]

  @Test("Expression.capturingRuntimeValues(_:) captures as intended", arguments: runtimeValueCaptureArguments)
  func expressionRuntimeValueCapture(arguments :RuntimeValueCaptureArguments) throws {
    var expression = Expression.__fromSyntaxNode("abc123")
    #expect(expression.sourceCode == "abc123")
    #expect(expression.runtimeValue == nil)

    expression = expression.capturingRuntimeValues(arguments.value)
    #expect(expression.sourceCode == "abc123")
    let runtimeValue = try #require(expression.runtimeValue)
    #expect(String(describing: runtimeValue) == String(describing: arguments.value))
    #expect(runtimeValue.typeInfo.fullyQualifiedName == TypeInfo(describingTypeOf: arguments.value).fullyQualifiedName)
    #expect(runtimeValue.isCollection == (arguments.value is any Collection))
    try arguments.moreChecks(runtimeValue)
  }
}

#if canImport(XCTest)
import XCTest

final class IssueTests_XCT: XCTestCase {
  func testIsAndAsComparisons() async {
    let expectRecorded = expectation(description: "#expect recorded")
    let requireRecorded = expectation(description: "#require recorded")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      XCTAssertFalse(issue.isKnown)
      guard case let .expectationFailed(expectation) = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      let expandedExpressionDescription = expectation.evaluatedExpression.expandedDescription()
      XCTAssertTrue(expandedExpressionDescription.contains("someString() → \"abc123\""))
      XCTAssertTrue(expandedExpressionDescription.contains("Int → String"))

      if expectation.isRequired {
        requireRecorded.fulfill()
      } else {
        expectRecorded.fulfill()
      }
    }

    await Test { () throws in
      @Sendable func randomNumber() -> Any {
        Int.random(in: 0 ..< 100)
      }
      @Sendable func someString() -> Any {
        "abc123"
      }

      #expect(randomNumber() is Int)
      let _: Int = try #require(randomNumber() as? Int)
      #expect(someString() is String)
      #expect(someString() is Int) // raises issue
      let _: Int = try #require(someString() as? Int) // raises issue
    }.run(configuration: configuration)
    await fulfillment(of: [expectRecorded, requireRecorded], timeout: 0.0)
  }

  func testCastAsAnyProtocol() async {
    // Sanity check that we parse types cleanly.
    await Test {
      #expect((1 as Any) is any Numeric)
      _ = try #require((1 as Any) as? any Numeric)
    }.run(configuration: .init())
  }

  func testErrorCheckingWithExpect() async throws {
    let expectationFailed = expectation(description: "Expectation failed")
    expectationFailed.isInverted = true

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      guard case .expectationFailed = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      expectationFailed.fulfill()
    }

    @Sendable @available(*, noasync) func asyncNotRequired() {}

    let randomNumber = Int.random(in: 0 ... .max)
    await Test {
      #expect {
        asyncNotRequired()
        throw MyError()
      } throws: {
        $0 is MyError
      }
      #expect(throws: MyError.self) {
        asyncNotRequired()
        throw MyError()
      }
      #expect(throws: MyParameterizedError(index: randomNumber)) {
        asyncNotRequired()
        throw MyParameterizedError(index: randomNumber)
      }
      #expect(throws: Never.self) {}
      func genericExpectThrows(_ type: (some Error).Type) {
        #expect(throws: type) {}
      }
      genericExpectThrows(Never.self)
      func nonVoidReturning() throws -> Int { throw MyError() }
      #expect(throws: MyError.self) {
        try nonVoidReturning()
      }
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testErrorCheckingWithExpect_Mismatching() async throws {
    let expectationFailed = expectation(description: "Expectation failed")
    expectationFailed.expectedFulfillmentCount = 13

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      guard case .expectationFailed = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      expectationFailed.fulfill()
    }

    @Sendable @available(*, noasync) func asyncNotRequired() {}
    let randomNumber = Int.random(in: 0 ... .max)

    await Test {
      #expect {
        asyncNotRequired()
      } throws: {
        $0 is MyError
      }
      #expect(throws: MyError.self) {
        asyncNotRequired()
      }
      #expect(throws: MyParameterizedError(index: randomNumber)) {
        asyncNotRequired()
      }
      #expect(throws: MyError.self) {
        throw MyParameterizedError(index: 0)
      }
      #expect(throws: MyError()) {
        throw MyParameterizedError(index: 0)
      }
      #expect(throws: MyError.self) {
        throw MyDescriptiveError(description: "something wrong")
      }
      #expect(throws: MyError()) {
        throw MyDescriptiveError(description: "something wrong")
      }
      #expect {
        throw MyDescriptiveError(description: "something wrong")
      } throws: {
        _ in false
      }
      #expect(throws: Never.self) {
        throw MyError()
      }
      func genericExpectThrows(_ type: (some Error).Type) {
        #expect(throws: type) {
          throw MyError()
        }
      }
      genericExpectThrows(Never.self)
      func nonVoidReturning() throws -> Int { 0 }
      #expect(throws: MyError.self) {
        try nonVoidReturning()
      }
      #expect {
        throw MyError()
      } throws: { error in
        let parameterizedError = try #require(error as? MyParameterizedError)
        return parameterizedError.index == 123
      }
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testErrorCheckingWithExpect_mismatchedErrorDescription() async throws {
    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      guard case let .expectationFailed(expectation) = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      XCTAssertEqual(expectation.mismatchedErrorDescription, "an error was expected but none was thrown")
      expectationFailed.fulfill()
    }

    await Test {
      func voidReturning() throws {}
      #expect(throws: MyError.self) {
        try voidReturning()
      }
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testErrorCheckingWithExpect_mismatchedErrorDescription_nonVoid() async throws {
    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      guard case let .expectationFailed(expectation) = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      XCTAssertEqual(expectation.mismatchedErrorDescription, "an error was expected but none was thrown and \"0\" was returned")
      expectationFailed.fulfill()
    }

    await Test {
      func nonVoidReturning() throws -> Int { 0 }
      #expect(throws: MyError.self) {
        try nonVoidReturning()
      }
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testErrorCheckingWithExpectAsync() async throws {
    let expectationFailed = expectation(description: "Expectation failed")
    expectationFailed.isInverted = true

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      guard case .expectationFailed = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      expectationFailed.fulfill()
    }

    let randomNumber = Int.random(in: 0 ... .max)
    await Test {
      await #expect { () async throws in
        throw MyError()
      } throws: {
        $0 is MyError
      }
      await #expect(throws: MyError.self) { () async throws in
        throw MyError()
      }
      await #expect(throws: MyParameterizedError(index: randomNumber)) { () async throws in
        throw MyParameterizedError(index: randomNumber)
      }
      await #expect(throws: Never.self) { () async in }
      func genericExpectThrows(_ type: (some Error).Type) async {
        await #expect(throws: type) { () async in }
      }
      await genericExpectThrows(Never.self)
      func nonVoidReturning() async throws -> Int { throw MyError() }
      await #expect(throws: MyError.self) {
        try await nonVoidReturning()
      }
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testErrorCheckingWithExpectAsync_Mismatching() async throws {
    let expectationFailed = expectation(description: "Expectation failed")
    expectationFailed.expectedFulfillmentCount = 13

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      guard case .expectationFailed = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      expectationFailed.fulfill()
    }

    let randomNumber = Int.random(in: 0 ... .max)
    await Test {
      await #expect { () async in } throws: {
        $0 is MyError
      }
      await #expect(throws: MyError.self) { () async in }
      await #expect(throws: MyParameterizedError(index: randomNumber)) { () async in }
      await #expect(throws: MyError.self) { () async throws in
        throw MyParameterizedError(index: 0)
      }
      await #expect(throws: MyError()) { () async throws in
        throw MyParameterizedError(index: 0)
      }
      await #expect(throws: MyError.self) { () async throws in
        throw MyDescriptiveError(description: "something wrong")
      }
      await #expect(throws: MyError()) { () async throws in
        throw MyDescriptiveError(description: "something wrong")
      }
      await #expect { () async throws in
        throw MyDescriptiveError(description: "something wrong")
      } throws: {
        _ in false
      }
      await #expect(throws: Never.self) { () async throws in
        throw MyError()
      }
      func genericExpectThrows(_ type: (some Error).Type) async {
        await #expect(throws: type) { () async throws in
          throw MyError()
        }
      }
      await genericExpectThrows(Never.self)
      func nonVoidReturning() async throws -> Int { 0 }
      await #expect(throws: MyError.self) {
        try await nonVoidReturning()
      }
      await #expect { () async throws in
        throw MyError()
      } throws: { error in
        let parameterizedError = try #require(error as? MyParameterizedError)
        return parameterizedError.index == 123
      }
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testErrorCheckingWithExpectAsync_mismatchedErrorDescription() async throws {
    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      guard case let .expectationFailed(expectation) = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      XCTAssertEqual(expectation.mismatchedErrorDescription, "an error was expected but none was thrown")
      expectationFailed.fulfill()
    }

    await Test {
      func voidReturning() async throws {}
      await #expect(throws: MyError.self) {
        try await voidReturning()
      }
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testErrorCheckingWithExpectAsync_mismatchedErrorDescription_nonVoid() async throws {
    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      guard case let .expectationFailed(expectation) = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      XCTAssertEqual(expectation.mismatchedErrorDescription, "an error was expected but none was thrown and \"0\" was returned")
      expectationFailed.fulfill()
    }

    await Test {
      func nonVoidReturning() async throws -> Int { 0 }
      await #expect(throws: MyError.self) {
        try await nonVoidReturning()
      }
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testErrorCheckingWithExpect_ThrowingFromErrorMatcher() async throws {
    let errorCaught = expectation(description: "Error matcher's error caught")
    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case let .errorCaught(error) = issue.kind, error is MyParameterizedError {
        errorCaught.fulfill()
      } else if case .expectationFailed = issue.kind {
        expectationFailed.fulfill()
      }
    }

    await Test {
      #expect {
        throw MyError()
      } throws: { _ in
        throw MyParameterizedError(index: 0)
      }
    }.run(configuration: configuration)

    await fulfillment(of: [errorCaught, expectationFailed], timeout: 0.0)
  }

  func testErrorCheckingWithExpectAsync_ThrowingFromErrorMatcher() async throws {
    let errorCaught = expectation(description: "Error matcher's error caught")
    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case let .errorCaught(error) = issue.kind, error is MyParameterizedError {
        errorCaught.fulfill()
      } else if case .expectationFailed = issue.kind {
        expectationFailed.fulfill()
      }
    }

    await Test {
      await #expect {
        throw MyError()
      } throws: { (_) async throws in
        throw MyParameterizedError(index: 0)
      }
    }.run(configuration: configuration)

    await fulfillment(of: [errorCaught, expectationFailed], timeout: 0.0)
  }

  func testErrorCheckingWithRequire_ThrowingFromErrorMatcher() async throws {
    let errorCaught = expectation(description: "Error matcher's error caught")
    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case let .errorCaught(error) = issue.kind, error is MyParameterizedError {
        errorCaught.fulfill()
      } else if case .expectationFailed = issue.kind {
        expectationFailed.fulfill()
      }
    }

    await Test {
      try #require {
        throw MyError()
      } throws: { _ in
        throw MyParameterizedError(index: 0)
      }
      XCTFail("Should be unreachable")
    }.run(configuration: configuration)

    await fulfillment(of: [errorCaught, expectationFailed], timeout: 0.0)
  }

  func testErrorCheckingWithRequireAsync_ThrowingFromErrorMatcher() async throws {
    let errorCaught = expectation(description: "Error matcher's error caught")
    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case let .errorCaught(error) = issue.kind, error is MyParameterizedError {
        errorCaught.fulfill()
      } else if case .expectationFailed = issue.kind {
        expectationFailed.fulfill()
      }
    }

    await Test {
      try await #require {
        throw MyError()
      } throws: { (_) async throws in
        throw MyParameterizedError(index: 0)
      }
      XCTFail("Should be unreachable")
    }.run(configuration: configuration)

    await fulfillment(of: [errorCaught, expectationFailed], timeout: 0.0)
  }

  func testFail() async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      XCTAssertFalse(issue.isKnown)
      guard case .unconditional = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
    }

    await Test {
      Issue.record()
      Issue.record("Custom message")
    }.run(configuration: configuration)
  }

#if !SWT_NO_UNSTRUCTURED_TASKS
  func testFailWithoutCurrentTest() async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      XCTAssertFalse(issue.isKnown)
      XCTAssertNil(event.testID)
    }

    await Test {
      await Task.detached {
        _ = Issue.record()
      }.value
    }.run(configuration: configuration)
  }
#endif

  func testFailBecauseOfError() async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      XCTAssertFalse(issue.isKnown)
      guard case let .errorCaught(error) = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      XCTAssertTrue(error is MyError)
    }

    await Test {
      Issue.record(MyError())
      Issue.record(MyError(), "Custom message")
    }.run(configuration: configuration)
  }

  func testErrorPropertyValidForThrownErrors() async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      XCTAssertFalse(issue.isKnown)
      XCTAssertNotNil(issue.error)
    }
    await Test {
      throw MyError()
    }.run(configuration: configuration)
  }

  func testErrorPropertyNilForOtherIssueKinds() async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      XCTAssertFalse(issue.isKnown)
      XCTAssertNil(issue.error)
    }
    await Test {
      Issue.record()
    }.run(configuration: configuration)
  }

  func testGetSourceLocationProperty() async throws {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      XCTAssertFalse(issue.isKnown)
      guard let sourceLocation = issue.sourceLocation else {
        return XCTFail("Expected a source location")
      }
      XCTAssertEqual(sourceLocation.fileID, #fileID)
    }
    await Test {
      Issue.record()
      Issue.record("Custom message")
    }.run(configuration: configuration)
  }

  func testSetSourceLocationProperty() async throws {
    let sourceLocation = SourceLocation(line: 12345)
    var issue = Issue(kind: .unconditional, comments: [], sourceContext: .init(sourceLocation: sourceLocation))

    var issueSourceLocation = try XCTUnwrap(issue.sourceLocation)
    XCTAssertEqual(issueSourceLocation.line, 12345)

    issue.sourceLocation?.line = 67890

    issueSourceLocation = try XCTUnwrap(issue.sourceLocation)
    XCTAssertEqual(issueSourceLocation.line, 67890)
  }

  func testDescriptionProperties() {
    do {
      let sourceLocation = SourceLocation.init(fileID: "FakeModule/FakeFile.swift", line: 9999, column: 1)
      let issue = Issue(kind: .system, comments: ["Some issue"], sourceContext: SourceContext(sourceLocation: sourceLocation))
      XCTAssertEqual(issue.description, "A system failure occurred: Some issue")
      XCTAssertEqual(issue.debugDescription, "A system failure occurred at FakeFile.swift:9999:1: Some issue")
    }
    do {
      let issue = Issue(kind: .system, comments: ["Some issue"], sourceContext: SourceContext(sourceLocation: nil))
      XCTAssertEqual(issue.debugDescription, "A system failure occurred: Some issue")
    }
  }

  func testCollectionDifference() async {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      guard case let .expectationFailed(expectation) = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      guard let differenceDescription = expectation.differenceDescription else {
        return XCTFail("Unexpected nil differenceDescription")
      }
      XCTAssertTrue(differenceDescription.contains("inserted ["))
      XCTAssertTrue(differenceDescription.contains("removed ["))
    }

    await Test {
      let lhs = [1, 2, 3, 4, 5]
      let rhs = [1, 2, 4, 3, 7, 5, 6]
      #expect(lhs == rhs)
    }.run(configuration: configuration)
  }

  func testCollectionDifferenceSkippedForStrings() async {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      guard case let .expectationFailed(expectation) = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      XCTAssertNil(expectation.differenceDescription)
    }

    await Test {
      #expect("hello" == "helbo")
    }.run(configuration: configuration)
  }

  func testNegatedExpressions() async {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      if case let .issueRecorded(issue) = event.kind {
        XCTFail("Unexpected issue \(issue)")
      }
    }

    await Test {
      #expect(!Bool(false))
      #expect(Bool((!false)))
      #expect(Bool((!(false))))
      #expect(!(!true))
      #expect(!(1 > 2))
    }.run(configuration: configuration)
  }

  func testNegatedExpressionsHaveCorrectCapturedExpressions() async {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      XCTAssertEqual(issue.comments.first, "!(   Bool(false)    )")
    }

    await Test {
      #expect(!(   Bool(false)    ))
    }.run(configuration: configuration)
  }

  func testLazyExpectDoesNotEvaluateRightHandValue() async {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      XCTAssertFalse(issue.isKnown)
      guard case let .expectationFailed(expectation) = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      let expression = expectation.evaluatedExpression
      XCTAssertTrue(expression.expandedDescription().contains("<not evaluated>"))
    }

    @Sendable func rhs() -> Bool {
      XCTFail("Invoked RHS function")
      return false
    }

    await Test {
      #expect(false && rhs())
    }.run(configuration: configuration)
  }

  func testLazyExpectEvaluatesRightHandValueWhenNeeded() async {
    let rhsCalled = expectation(description: "RHS function called")
    @Sendable func rhs() -> Bool {
      rhsCalled.fulfill()
      return true
    }

    await Test {
      #expect(false || rhs())
    }.run()

    await fulfillment(of: [rhsCalled], timeout: 0.0)
  }

  func testRequireOptionalMemberAccessEvaluatesToNil() async {
    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      XCTAssertFalse(issue.isKnown)
      guard case let .expectationFailed(expectation) = issue.kind else {
        XCTFail("Unexpected issue kind \(issue.kind)")
        return
      }
      let expression = expectation.evaluatedExpression
      XCTAssertTrue(expression.expandedDescription().contains("nil"))
      XCTAssertFalse(expression.expandedDescription().contains("<not evaluated>"))
    }

    await Test {
      let array = [String]()
      _ = try #require(array.first)
    }.run(configuration: configuration)
  }

  func testOptionalOperand() async {
    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case let .expectationFailed(expectation) = issue.kind {
        expectationFailed.fulfill()
        let desc = expectation.evaluatedExpression.expandedDescription()
        XCTAssertTrue(desc.contains("7"))
        XCTAssertFalse(desc.contains("Optional(7)"))
      }
    }

    await Test {
      let nonNilOptional: Int? = 7
      #expect(nonNilOptional == 8)
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testNilOptionalOperand() async {
    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case let .expectationFailed(expectation) = issue.kind {
        expectationFailed.fulfill()
        let desc = expectation.evaluatedExpression.expandedDescription()
        XCTAssertTrue(desc.contains("nil"))
      }
    }

    await Test {
      let optionalValue: Int? = nil
      #expect(optionalValue == 8)
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testNilOptionalCallResult() async {
    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case let .expectationFailed(expectation) = issue.kind {
        expectationFailed.fulfill()
        let desc = expectation.evaluatedExpression.expandedDescription()
        XCTAssertTrue(desc.contains("nil"))
      }
    }

    @Sendable func f() -> Int? { nil }

    await Test {
      _ = try #require(f())
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testCustomTestStringConvertible() async {
    struct Food: CustomTestStringConvertible {
      func addSeasoning() -> Bool { false }
      var testDescription: String {
        "Delicious Food, Yay!"
      }
    }

    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case let .expectationFailed(expectation) = issue.kind {
        expectationFailed.fulfill()
        let desc = expectation.evaluatedExpression.expandedDescription()
        XCTAssertTrue(desc.contains("Delicious Food, Yay!"))
      }
    }

    await Test {
      #expect(Food().addSeasoning())
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testEnumDescription() async throws {
    guard #available(_mangledTypeNameAPI, *) else {
      throw XCTSkip("Unavailable")
    }

    enum E: CaseIterable {
      case a
      case b
    }

    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case let .expectationFailed(expectation) = issue.kind {
        expectationFailed.fulfill()
        let desc = expectation.evaluatedExpression.expandedDescription()
        XCTAssertTrue(desc.contains(".b"))
        XCTAssertFalse(desc.contains("→ .b"))
      }
    }

    await Test(arguments: E.allCases) { e in
      #expect(e == .b)
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testEnumWithCustomDescription() async {
    enum E: CaseIterable, CustomStringConvertible {
      case a
      case b
      var description: String {
        "customDesc"
      }
    }

    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case let .expectationFailed(expectation) = issue.kind {
        expectationFailed.fulfill()
        let desc = expectation.evaluatedExpression.expandedDescription()
        XCTAssertTrue(desc.contains(".b → customDesc"))
        XCTAssertFalse(desc.contains(".customDesc"))
      }
    }

    await Test(arguments: E.allCases) { e in
      #expect(e == .b)
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }

  func testCEnumDescription() async throws {
    guard #available(_mangledTypeNameAPI, *) else {
      throw XCTSkip("Unavailable")
    }

    let expectationFailed = expectation(description: "Expectation failed")

    var configuration = Configuration()
    configuration.eventHandler = { event, _ in
      guard case let .issueRecorded(issue) = event.kind else {
        return
      }
      if case let .expectationFailed(expectation) = issue.kind {
        expectationFailed.fulfill()
        let desc = expectation.evaluatedExpression.expandedDescription()
        XCTAssertTrue(desc.contains(".A → SWTTestEnumeration(rawValue: \(SWTTestEnumeration.A.rawValue))"))
        XCTAssertFalse(desc.contains(".SWTTestEnumeration"))
      }
    }

    await Test(arguments: [SWTTestEnumeration.A, SWTTestEnumeration.B]) { e in
      #expect(e == .A)
    }.run(configuration: configuration)

    await fulfillment(of: [expectationFailed], timeout: 0.0)
  }
}
#endif

@Suite("Issue Codable Conformance Tests")
struct IssueCodingTests {

  private static let issueKinds: [Issue.Kind] = [
    Issue.Kind.apiMisused,
    Issue.Kind.confirmationMiscounted(actual: 13, expected: 42),
    Issue.Kind.errorCaught(NSError(domain: "Domain", code: 13, userInfo: ["UserInfoKey": "UserInfoValue"])),
    Issue.Kind.expectationFailed(Expectation(evaluatedExpression: .__fromSyntaxNode("abc"), isPassing: true, isRequired: true, sourceLocation: SourceLocation())),
    Issue.Kind.knownIssueNotRecorded,
    Issue.Kind.system,
    Issue.Kind.timeLimitExceeded(timeLimitComponents: (13, 42)),
    Issue.Kind.unconditional,
  ]

  @Test("Codable",
    arguments: issueKinds
  )
  func testCodable(issueKind: Issue.Kind) async throws {
    let issue = Issue(
      kind: issueKind,
      comments: ["Comment"],
      sourceContext: SourceContext(backtrace: Backtrace.current(), sourceLocation: SourceLocation())
    )
    let issueSnapshot = Issue.Snapshot(snapshotting: issue)
    let decoded = try JSON.encodeAndDecode(issueSnapshot)

    #expect(String(describing: decoded) == String(describing: issueSnapshot))
  }

  @Test func errorSnapshot() throws {
    let issue = Issue(kind: .errorCaught(NSError(domain: "Domain", code: 13)), comments: [])
    let underlyingError = try #require(issue.error)

    let issueSnapshot = Issue.Snapshot(snapshotting: issue)
    let errorSnapshot = try #require(issueSnapshot.error)
    #expect(String(describing: errorSnapshot) == String(describing: underlyingError))
  }

  @Test func sourceLocationPropertyGetter() throws {
    let sourceLocation = SourceLocation(
      fileID: "fileID",
      filePath: "filePath",
      line: 13,
      column: 42
    )

    let sourceContext = SourceContext(
      backtrace: Backtrace(addresses: [13, 42]),
      sourceLocation: sourceLocation
    )

    let issue = Issue(
      kind: .apiMisused,
      comments: [],
      sourceContext: sourceContext
    )

    let issueSnapshot = Issue.Snapshot(snapshotting: issue)
    #expect(issueSnapshot.sourceContext == sourceContext)
    #expect(issueSnapshot.sourceLocation == sourceLocation)
  }

  @Test func sourceLocationPropertySetter() throws {
    let initialSourceLocation = SourceLocation(
      fileID: "fileID",
      filePath: "filePath",
      line: 13,
      column: 42
    )

    let sourceContext = SourceContext(
      backtrace: Backtrace(addresses: [13, 42]),
      sourceLocation: initialSourceLocation
    )

    let issue = Issue(
      kind: .apiMisused,
      comments: [],
      sourceContext: sourceContext
    )

    let updatedSourceLocation = SourceLocation(
      fileID: "fileID2",
      filePath: "filePath2",
      line: 14,
      column: 43
    )

    var issueSnapshot = Issue.Snapshot(snapshotting: issue)
    issueSnapshot.sourceLocation = updatedSourceLocation

    #expect(issueSnapshot.sourceContext != sourceContext)
    #expect(issueSnapshot.sourceLocation != initialSourceLocation)
    #expect(issueSnapshot.sourceLocation == updatedSourceLocation)
    #expect(issueSnapshot.sourceContext.sourceLocation == updatedSourceLocation)
  }

  @Test("Custom descriptions are the same",
    arguments: issueKinds
  )
  func customDescription(issueKind: Issue.Kind) async throws {
    let issue = Issue(
      kind: issueKind,
      comments: ["Comment"],
      sourceContext: SourceContext(backtrace: Backtrace.current(), sourceLocation: SourceLocation())
    )
    let issueSnapshot = Issue.Snapshot(snapshotting: issue)

    #expect(String(describing: issueSnapshot) == String(describing: issue))
    #expect(String(reflecting: issueSnapshot) == String(reflecting: issue))
  }
}

// MARK: - Fixtures

struct TypeWithMemberFunctions {
  static func f(_ x: Int) -> Bool { false }
  static func g(label x: Int) -> Bool { false }
  static func h(_ x: () -> Void) -> Bool { false }
  static func j(_ x: Int) -> Never? { nil }
  static func k(_ x: inout Int) -> Bool { false }
  static func m(_ x: Bool) -> Bool { false }
  static func n(_ x: Int) throws -> Bool { false }
}

struct ExpressionRuntimeValueCapture_Value: Sendable {}

struct ExpressionRuntimeValueCapture_ValueWithChildren: Sendable {
  var contents: [any Sendable] = []
}
