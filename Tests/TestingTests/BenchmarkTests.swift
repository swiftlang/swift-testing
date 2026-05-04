//
//  BenchmarkTests.swift
//  swift-testing
//
//  Created by Harlan Haskins on 8/24/26.
//

@testable import Testing

@inline(never)
func _blackHole<T>(_ x: T) {
}

@Benchmark(.warmup(100), arguments: [100, 1000, 100000, 1000000])
func exampleBenchmark(n: Int) {
  let numbers = (0..<n).map { _ in Int.random(in: 0..<1000000) }
  _blackHole(numbers.sorted())
}
