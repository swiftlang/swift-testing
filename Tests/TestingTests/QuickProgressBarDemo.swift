import Testing
import Foundation

@Suite("Quick Progress Bar Demo - 10 seconds total", .serialized)
struct QuickProgressBarDemo {
    
    @Test("Test 1 - 1.5s")
    func test1() async throws {
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        #expect(1 + 1 == 2)
    }
    
    @Test("Test 2 - 2s") 
    func test2() async throws {
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        #expect(2 + 2 == 4)
    }
    
    @Test("FAILING Test - 1s")
    func failingTest() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        #expect(1 + 1 == 3, "This will fail!")
    }
    
    @Test("Test 3 - 2.5s")
    func test3() async throws {
        try await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
        #expect(3 + 3 == 6)
    }
    
    @Test("Test 4 - 3s")
    func test4() async throws {
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        #expect(4 + 4 == 8)
    }
} 