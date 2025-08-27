//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
private import _TestingInternals

#if canImport(Foundation)
import Foundation
#endif

@Suite("Parallelization Trait Tests", .tags(.traitRelated))
struct ParallelizationTraitTests {
  @Test(".serialized trait serializes parameterized test", arguments: await [
    Runner.Plan(selecting: OuterSuite.self),
    Runner.Plan(selecting: "globalParameterized(i:)"),
  ])
  func serializesParameterizedTestFunction(plan: Runner.Plan) async {
    var configuration = Configuration()
    configuration.isParallelizationEnabled = true

    let indicesRecorded = Locked<[Int]>()
    configuration.eventHandler = { event, _ in
      if case let .issueRecorded(issue) = event.kind,
         let comment = issue.comments.first,
         comment.rawValue.hasPrefix("PARAMETERIZED") {
        // Silly hack: only letters before the index, so just scrape off all
        // leading letters and what's left will be the index as a string. No
        // need for sscanf() or similar.
        if let index = Int(String(comment.rawValue.drop(while: \.isLetter))) {
          indicesRecorded.withLock { indicesRecorded in
            indicesRecorded.append(index)
          }
        }
      }
    }

    let runner = Runner(plan: plan, configuration: configuration)
    await runner.run()

    let indicesRecordedValue = indicesRecorded.rawValue
    #expect(indicesRecordedValue.count == 10_000)
    let isSorted = indicesRecordedValue == indicesRecordedValue.sorted()
    #expect(isSorted)
  }
}

// MARK: -

@Suite("Parallelization Trait Tests with Dependencies")
struct ParallelizationTraitTestsWithDependencies {
  func dependency() throws -> ParallelizationTrait.Dependency.Kind {
    let traits = try #require(Test.current?.traits.compactMap { $0 as? ParallelizationTrait })
    try #require(traits.count == 1)
    return try #require(traits[0].dependency?.kind)
  }

  @Test(.serialized(for: Dependency1.self))
  func type() throws {
    let dependency = try dependency()
    #expect(dependency == .keyPath(\Dependency1.self))
  }

  @Test(.serialized(for: Dependency1.self), .serialized(for: Dependency1.self))
  func duplicates() throws {
    let dependency = try dependency()
    #expect(dependency == .keyPath(\Dependency1.self))
  }

  @Test(.serialized(for: Dependency1.self), .serialized(for: Dependency2.self))
  func multiple() throws {
    let dependency = try dependency()
    #expect(dependency == .unbounded)
  }

  @Test(.serialized(for: Dependency1.self), .serialized, arguments: [0])
  func mixedDependencyAndNot(_: Int) throws {
    let dependency = try dependency()
    #expect(dependency == .keyPath(\Dependency1.self))
  }

  @Test(.serialized, .serialized(for: Dependency1.self), arguments: [0])
  func mixedNotAndDependency(_: Int) throws {
    let dependency = try dependency()
    #expect(dependency == .keyPath(\Dependency1.self))
  }

  @Test(unsafe .serialized(for: dependency3))
  func pointer() throws {
    let dependency = try dependency()
    #expect(dependency == .address(dependency3))
  }

  @Test(unsafe .serialized(for: dependency3), unsafe .serialized(for: dependency4))
  func multiplePointers() throws {
    let dependency = try dependency()
    #expect(dependency == .unbounded)
  }

  @Test(.serialized(for: .tagDependency))
  func tag() throws {
    let dependency = try dependency()
    #expect(dependency == .tag(.tagDependency))
  }

  @Test(.serialized(for: Environment.self))
  func environment() throws {
    let dependency = try dependency()
    #expect(dependency == .environ)
  }

#if !SWT_NO_ENVIRONMENT_VARIABLES
#if canImport(Foundation)
  @Test(.serialized(for: ProcessInfo.self))
  func foundationEnvironment() throws {
    let dependency = try dependency()
    #expect(dependency == .environ)
  }
#endif

#if SWT_TARGET_OS_APPLE
  @Test(unsafe .serialized(for: _NSGetEnviron()))
  func appleCRTEnvironOuterPointer() throws {
    let dependency = try dependency()
    #expect(dependency == .environ)
  }

  @Test(unsafe .serialized(for: _NSGetEnviron()!.pointee!))
  func appleCRTEnviron() throws {
    let dependency = try dependency()
    #expect(dependency == .environ)
  }
#elseif os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android)
  @Test(unsafe .serialized(for: swt_environ()))
  func posixEnviron() throws {
    let dependency = try dependency()
    #expect(dependency == .environ)
  }
#elseif os(WASI)
  @Test(unsafe .serialized(for: __wasilibc_get_environ()))
  func wasiEnviron() throws {
    let dependency = try dependency()
    #expect(dependency == .environ)
  }
#endif
#endif
}

// MARK: - Fixtures

@Suite(.hidden, .serialized)
private struct OuterSuite {
  /* This @Suite intentionally left blank */ struct IntermediateSuite {
    @Suite(.hidden)
    struct InnerSuite {
      @Test(.hidden) func example() {}

      @Test(.hidden, arguments: 0 ..< 10_000) func parameterized(i: Int) async throws {
        Issue.record("PARAMETERIZED\(i)")
      }
    }
  }
}

@Test(.hidden, .serialized, arguments: 0 ..< 10_000)
private func globalParameterized(i: Int) {
  Issue.record("PARAMETERIZED\(i)")
}

private struct Dependency1 {
  var x = 0
  var y = 0
}

private struct Dependency2 {}

private nonisolated(unsafe) let dependency3 = UnsafeMutablePointer<CChar>.allocate(capacity: 1)

private nonisolated(unsafe) let dependency4 = UnsafeMutablePointer<CChar>.allocate(capacity: 1)

extension Tag {
  @Tag fileprivate static var tagDependency: Self
}
