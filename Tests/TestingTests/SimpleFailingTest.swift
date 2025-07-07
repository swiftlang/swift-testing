/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

/// Simple failing test to verify hierarchical output with issues as sub-nodes
@Suite("Simple Failing Suite") 
struct SimpleFailingTest {
  
  @Test("Test with single failure")
  func testSingleFailure() async throws {
    let result = 1 + 1
    #expect(result == 3, "Math should work: 1 + 1 should equal 3")
  }
  
  @Test("Test with multiple failures") 
  func testMultipleFailures() async throws {
    let name = "Alice"
    let age = 25
    let isActive = true
    
    #expect(name == "Bob", "Name should be Bob")
    #expect(age == 30, "Age should be 30") 
    #expect(isActive == false, "Should be inactive")
  }
  
  @Test("Test that passes")
  func testThatPasses() async throws {
    #expect(true)
    #expect(1 == 1)
  }
  
  @Suite("Nested Suite")
  struct NestedFailingTests {
    
    @Test("Nested test with failures")
    func nestedFailingTest() async throws {
      let array = [1, 2, 3]
      #expect(array.count == 5, "Array should have 5 elements")
      #expect(array.first == 2, "First element should be 2")
    }
    
    @Test("Nested test that passes")
    func nestedPassingTest() async throws {
      #expect(true)
    }
  }
} 