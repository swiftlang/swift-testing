//
//  Untitled.swift
//  swift-testing
//
//  Created by Harlan Haskins on 5/4/26.
//

public struct BenchmarkScale: BenchmarkTrait, TestScoping {
  public var repetitions: Int

  public func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: () async throws -> Void
  ) async throws {
    var config = Configuration.current ?? .init()
    config.benchmarkOptions.repetitions = repetitions
    try await Configuration.withCurrent(config) {
      try await function()
    }
  }
}

extension Trait where Self == BenchmarkScale {
  public static func scale(_ repetitions: Int) -> BenchmarkScale {
    .init(repetitions: repetitions)
  }
}

public struct BenchmarkWarmup: BenchmarkTrait, TestScoping {
  public var repetitions: Int

  public func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: () async throws -> Void
  ) async throws {
    var config = Configuration.current ?? .init()
    config.benchmarkOptions.warmup = repetitions
    try await Configuration.withCurrent(config) {
      try await function()
    }
  }
}

extension Trait where Self == BenchmarkWarmup {
  public static func warmup(_ repetitions: Int) -> BenchmarkWarmup {
    .init(repetitions: repetitions)
  }
}
