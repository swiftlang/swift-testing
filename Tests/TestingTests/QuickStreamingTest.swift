import Testing
import Foundation

@Suite("SF Symbol Showcase Suite")
struct QuickStreamingTest {
  
  // MARK: - Passing Tests (Green checkmark.circle)
  
  @Test("Simple passing test")
  func simplePassingTest() {
    #expect(Bool(true))
    #expect(2 + 2 == 4)
  }
  
  @Test("Fast async test")
  func fastAsyncTest() async {
    #expect(Bool(true))
  }
  
  @Test("Math calculations")
  func mathCalculations() {
    let result = 10 * 5
    #expect(result == 50)
    #expect(result > 40)
  }
  
  // MARK: - Failing Tests (Red x.circle)
  
  @Test("Simple failing test")
  func simpleFailingTest() {
    #expect(Bool(false), "This test is designed to fail")
  }
  
  @Test("Math failure")
  func mathFailure() {
    #expect(2 + 2 == 5, "Math doesn't work that way!")
  }
  
  @Test("String comparison failure")
  func stringComparisonFailure() {
    let greeting = "Hello"
    #expect(greeting == "Goodbye", "Greeting mismatch")
  }
  
  // MARK: - Difference Tests (Brown notequal.circle)
  
  @Test("Array difference test")
  func arrayDifferenceTest() {
    let expected = ["apple", "banana", "cherry"]
    let actual = ["apple", "grape", "cherry"]
    #expect(actual == expected, "Arrays should match")
  }
  
  @Test("String difference test")
  func stringDifferenceTest() {
    let expected = "The quick brown fox jumps over the lazy dog"
    let actual = "The quick red fox jumps over the lazy cat"
    #expect(actual == expected, "Strings should match")
  }
  
  // MARK: - Skipped Tests (Purple forward.circle)
  
  @Test("Disabled test", .disabled("This test is intentionally disabled"))
  func disabledTest() {
    #expect(Bool(true))
  }
  
  @Test("Another skipped test", .disabled("Not ready yet"))
  func anotherSkippedTest() {
    #expect(2 + 2 == 4)
  }
  
  // MARK: - Tests with Known Issues (Gray x.circle)
  
  @Test("Test with known issue")
  func testWithKnownIssue() {
    withKnownIssue("This is a known bug that will be fixed later") {
      #expect(Bool(false), "Known failing condition")
    }
    #expect(Bool(true), "This part should pass")
  }
  
  @Test("Another known issue")
  func anotherKnownIssue() {
    withKnownIssue("Legacy API compatibility issue") {
      #expect(1 == 2, "This fails but it's expected")
    }
    #expect("test".count == 4)
  }
  
  // MARK: - Warning Tests (Orange exclamationmark.circle)
  
  @Test("Test with warning issue")
  func testWithWarningIssue() {
    Issue.record("This is a warning level issue")
    #expect(Bool(true), "Test should still pass despite warning")
  }
  
  @Test("Performance warning test")
  func performanceWarningTest() {
    Issue.record("Performance might be degraded")
    #expect(10 > 5)
  }
  
  // MARK: - Complex Test Scenarios
  
  @Test("Mixed scenario test")
  func mixedScenarioTest() {
    // Issue record
    Issue.record("Complex test scenario detected")
    
    // Known issue
    withKnownIssue("Complex scenarios have edge cases") {
      #expect(Bool(false), "Edge case failure")
    }
    
    // Final assertion should pass
    #expect(Bool(true), "Main functionality works")
  }
  
  @Test("Parameterized test", arguments: [1, 2, 3, 4, 5])
  func parameterizedTest(value: Int) {
    #expect(value > 0)
    #expect(value <= 5)
  }
  
  @Test("Error throwing test")
  func errorThrowingTest() throws {
    struct TestError: Error {
      let message: String
    }
    
    // This should fail
    throw TestError(message: "Intentional test error")
  }
  
  
  @Test("Complex object comparison")
  func complexObjectComparison() {
    struct Person {
      let name: String
      let age: Int
      let city: String
    }
    
    let expected = Person(name: "John", age: 30, city: "New York")
    let actual = Person(name: "Jane", age: 25, city: "Boston")
    
    #expect(actual.name == expected.name, "Names should match")
    #expect(actual.age == expected.age, "Ages should match")
    #expect(actual.city == expected.city, "Cities should match")
  }
  
  // MARK: - Attachment Tests (Gray paperclip.circle)
  
  @Test("Test with actual attachment")
  func testWithActualAttachment() {
    // Create some test data to attach
    let testData = Data("This is test attachment content for demonstration".utf8)
    
    // Attach the data to this test - this should trigger .valueAttached event
    Attachment.record(testData, named: "test-data.txt")
    
    // The test should still pass
    #expect(testData.count > 0, "Data should have content")
  }
  
  @Test("Test with string attachment")
  func testWithStringAttachment() {
    // Create a string attachment
    let logContent = """
    Test Log Entry:
    Timestamp: \(Date())
    Status: Running attachment demonstration
    Result: Success
    """
    
    // Attach the string to this test
    Attachment.record(logContent, named: "test-log.txt")
    
    #expect(logContent.contains("Success"), "Log should contain success")
  }
  
  // MARK: - Detailed comparison tests
}

// MARK: - Nested Suite to Show Hierarchy

@Suite("Nested Suite Example")
struct NestedSuiteExample {
  
  @Suite("Sub-Suite Level 1")
  struct SubSuite1 {
    
    @Test("Nested passing test")
    func nestedPassingTest() {
      #expect(Bool(true))
    }
    
    @Test("Nested failing test")
    func nestedFailingTest() {
      #expect(Bool(false), "Nested failure")
    }
    
    @Test("Nested difference test")
    func nestedDifferenceTest() {
      let numbers = [1, 2, 3, 4, 5]
      let expected = [1, 2, 99, 4, 5]
      #expect(numbers == expected, "Number arrays should match")
    }
    
    @Suite("Sub-Suite Level 2")
    struct SubSuite2 {
      
      @Test("Deep nested test")
      func deepNestedTest() {
        #expect("nested".count == 6)
      }
      
      @Test("Deep nested with issue")
      func deepNestedWithIssue() {
        Issue.record("Deep nesting detected")
        #expect(Bool(true))
      }
      
      @Test("Deep nested difference")
      func deepNestedDifference() {
        let dict1 = ["key1": "value1", "key2": "value2"]
        let dict2 = ["key1": "value1", "key2": "different"]
        #expect(dict1 == dict2, "Dictionaries should match")
      }
    }
  }
} 