/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

#if canImport(XCTest) && _runtime(_ObjC)
import XCTest
@testable @_spi(ExperimentalTestRunning) @_spi(ExperimentalEventHandling) import Testing

final class NonXCTestCaseClassTests: NSObject {
  @Test func testFunctionThatLooksLikeXCTest() {
    #expect(Test.current?.xcTestCompatibleSelector != nil)
  }
}

@Suite("Objective-C Interop Tests")
struct ObjCInteropTests {
  @TaskLocal static var areObjCClassTestsEnabled = false

  class IndirectXCTestCase: XCTestCase {}

  @Suite(.hidden, .enabled(if: ObjCInteropTests.areObjCClassTestsEnabled))
  final class ObjCClassTests: IndirectXCTestCase {
    @Test(.hidden)
    @objc(testExplicitName) func wrongAnswer() {}

    @Test(.hidden)
    @objc(testExplicitNameWithCompletionHandler:) func wrongAnswerAsync() async {}

    @Test(.hidden)
    @objc(testExplicitNameThrowsFunError:) func wrongAnswerThrows() throws {}

    @Test(.hidden)
    @objc(testExplicitNameAsyncThrowsWithCompletionHandler:) func wrongAnswerAsyncThrows() async throws {}

    @Test(.hidden)
    @objc(`testExplicitNameWithBackticks`) func wrongAnswerWithBackticks() {}

    @Test(.hidden)
    func testImplicitName() {}

    @Test(.hidden)
    func `testImplicitNameWithBackticks`() {}

    @Test(.hidden)
    func testAsynchronous() async {}

    @Test(.hidden)
    func testThrowing() throws {}

    @Test(.hidden)
    func testAsynchronousThrowing() async throws {}
  }

  @Test("Objective-C selectors")
  func objCSelectors() async throws {
    let testPlan = await Runner.Plan(selecting: ObjCClassTests.self)
    let steps = testPlan.steps.filter { !$0.test.isSuite }
    #expect(steps.count > 0)
    for step in steps {
      let selector = try #require(step.test.xcTestCompatibleSelector)
      let testCaseClass = try #require(step.test.containingType as? NSObject.Type)
      #expect(testCaseClass.instancesRespond(to: selector))
    }
  }

  @Test("Objective-C methods are currently unsupported")
  func objCMethodsCurrentlyUnsupported() async throws {
    await confirmation("XCTestCase issue recorded", expectedCount: 10) { issueRecorded in
      var configuration = Configuration()
      configuration.eventHandler = { event in
        if case let .issueRecorded(issue) = event.kind,
           case .apiMisused = issue.kind,
           let comment = issue.comments.first,
           comment == "The @Test attribute cannot be applied to methods on a subclass of XCTestCase." {
          issueRecorded()
        }
      }
      await Self.$areObjCClassTestsEnabled.withValue(true) {
        await runTest(for: ObjCClassTests.self, configuration: configuration)
      }
    }
  }
}
#endif
