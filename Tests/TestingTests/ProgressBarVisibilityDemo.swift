import Testing
import Foundation

@Suite("Progress Bar Visibility Demo - Watch the progress bar update!", .serialized)
struct ProgressBarVisibilityDemo {
    
    @Test("Slow Test 1 - 2 seconds")
    func slowTest1() async throws {
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        #expect(1 + 1 == 2)
    }
    
    @Test("Slow Test 2 - 3 seconds") 
    func slowTest2() async throws {
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        #expect(2 + 2 == 4)
    }
    
    @Test("Failing Slow Test - 2.5 seconds")
    func failingSlowTest() async throws {
        try await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
        #expect(1 + 1 == 3, "This test will fail after waiting 2.5 seconds")
    }
    
    @Test("Slow Test 3 - 4 seconds")
    func slowTest3() async throws {
        try await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
        #expect(3 + 3 == 6)
    }
    
    @Test("Another Failing Test - 1.5 seconds")
    func anotherFailingTest() async throws {
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        #expect(2 + 2 == 5, "Another failure after 1.5 seconds")
    }
    
    @Test("Slow Test 4 - 3.5 seconds")
    func slowTest4() async throws {
        try await Task.sleep(nanoseconds: 3_500_000_000) // 3.5 seconds
        #expect(4 + 4 == 8)
    }
    
    @Test("Final Slow Test - 2 seconds")
    func finalSlowTest() async throws {
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        #expect(5 + 5 == 10)
    }
} 