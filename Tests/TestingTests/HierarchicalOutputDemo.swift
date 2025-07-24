//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) import Testing
import Foundation

@Suite("HierarchicalOutputDemoSuite")
struct HierarchicalOutputDemoSuite {
  
  @Test("passingTest")
  func passingTest() {
    #expect(1 + 1 == 2)
  }
  
  @Test("anotherPassingTest")
  func anotherPassingTest() {
    #expect(true == true)
  }
  
  @Test("failingTest")
  func failingTest() {
    #expect(1 + 1 == 3)
  }
  
  static func shouldSkipTest() -> Bool {
    // This will always return false (i.e., should skip), but is evaluated at runtime
    return ProcessInfo.processInfo.environment["NEVER_SET_ENV_VAR"] != nil
  }
  
  @Test("skippedTest", .enabled { shouldSkipTest() })
  func skippedTest() {
    #expect(1 + 1 == 2)
  }
  
  @Test("anotherSkippedTest", .disabled { !shouldSkipTest() })
  func anotherSkippedTest() {
    #expect(true == true)
  }
}

@Suite("AnotherTestSuite")
struct AnotherTestSuite {
  
  @Test("quickTest")
  func quickTest() {
    #expect(2 + 2 == 4)
  }
  
  @Test("slightlySlowerTest")
  func slightlySlowerTest() {
    #expect(3 + 3 == 6)
  }
  
  @Test("skipInAnotherSuite", .enabled { HierarchicalOutputDemoSuite.shouldSkipTest() })
  func skipInAnotherSuite() {
    #expect(1 + 1 == 2)
  }
} 