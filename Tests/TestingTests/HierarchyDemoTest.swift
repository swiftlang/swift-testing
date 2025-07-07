/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

/// Simple hierarchy demo test to showcase Advanced Console Output
@Suite("Hierarchy Demo")
struct HierarchyDemoTest {
  
  @Suite("User Tests")
  struct UserTests {
    
    @Test("Valid user creation")
    func testValidUserCreation() async throws {
      let user = User(name: "John", age: 25)
      #expect(user.name == "John")
      #expect(user.age == 25)
    }
    
    @Test("Invalid user age")
    func testInvalidUserAge() async throws {
      let user = User(name: "Alice", age: -5)
      // These expectations will fail to demonstrate issues as sub-nodes
      #expect(user.age > 0, "Age must be positive")
      #expect(user.age < 150, "Age must be reasonable")
    }
    
    @Test("Multiple validation failures")
    func testMultipleValidationFailures() async throws {
      let user = User(name: "", age: 200)
      // Multiple failing expectations to show multiple issues under one test
      #expect(!user.name.isEmpty, "Name cannot be empty")
      #expect(user.age > 0, "Age must be positive") 
      #expect(user.age < 150, "Age must be under 150")
    }
  }
  
  @Suite("Math Tests")
  struct MathTests {
    
    @Test("Basic arithmetic")
    func testBasicArithmetic() async throws {
      #expect(2 + 2 == 4)
      #expect(10 / 2 == 5)
    }
    
    @Test("Division validation")
    func testDivisionValidation() async throws {
      let divisor = 0
      // This expectation will fail
      #expect(divisor != 0, "Division by zero should be handled")
      
      let result = 10
      #expect(result > 5, "Result should be greater than 5")
    }
  }
  
  @Suite("Network Tests") 
  struct NetworkTests {
    
    @Test("Connection test")
    func testConnection() async throws {
      let isConnected = true
      #expect(isConnected == true)
    }
    
    @Test("Request validation")
    func testRequestValidation() async throws {
      let request = NetworkRequest(url: "invalid-url", timeout: -1)
      // Multiple failing expectations
      #expect(request.isValid, "Request should be valid")
      #expect(request.timeout > 0, "Timeout must be positive")
    }
  }
}

// Simple test data structures
struct User {
  let name: String
  let age: Int
}

struct NetworkRequest {
  let url: String
  let timeout: Double
  
  var isValid: Bool {
    return !url.isEmpty && url.contains("://") && timeout > 0
  }
} 