//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ForToolsIntegrationOnly) @testable import Testing

struct `Polymorphic test function tests` {
  @Test func `Polymorphic functions are discovered and run`() async throws {
    let testPlan = await Runner.Plan(selecting: PolymorphicBaseClass.self)
    let runner = Runner(plan: testPlan)
    let ranClasses = await $ranClasses.withValue(Allocated(Mutex([]))) {
      await runner.run()
      return $ranClasses.wrappedValue.value.rawValue
    }.sorted { $0.unqualifiedName < $1.unqualifiedName }
    let expectedClasses: [TypeInfo] = [
      TypeInfo(describing: PolymorphicBaseClass.self),
      TypeInfo(describing: PolymorphicBaseClass.DerivedClass.self),
      TypeInfo(describing: TertiaryClass.self),
    ].sorted { $0.unqualifiedName < $1.unqualifiedName }
    #expect(ranClasses == expectedClasses)
  }

  @Test func `Non-polymorphic subclass does not inherit test functions`() async throws {
    await confirmation("Test suite started", expectedCount: 1...) { suiteStarted in
      var configuration = Configuration()
      configuration.eventHandler = { event, eventContext in
        if case .testStarted = event.kind {
          let test = eventContext.test!
          if test.isSuite {
            suiteStarted()
          } else {
            Issue.record("Ran test function '\(eventContext.test!.name)' in what should have been an empty suite")
          }
        }
      }
      let testPlan = await Runner.Plan(selecting: PolymorphicBaseClass.DoesNotInheritBaseClass.DoesNotInheritDerivedClass.self, configuration: configuration)
      let runner = Runner(plan: testPlan, configuration: configuration)
      await runner.run()
    }
  }
}

// MARK: - Fixtures

@TaskLocal private var ranClasses = Allocated(Mutex<[TypeInfo]>([]))

@polymorphic @Suite(.hidden) private class PolymorphicBaseClass {
  @Test func `Invoke inherited test function`() {
    ranClasses.value.withLock { $0.append(TypeInfo(describing: Self.self)) }
  }

  required init() {}

  class DoesNotInheritBaseClass {
    @Test func `This function should not be inherited`() {
      Issue.record("Should not have run this function.")
    }

    @Suite final class DoesNotInheritDerivedClass: DoesNotInheritBaseClass {}
  }

  class DerivedClass: PolymorphicBaseClass {}
}

private final class TertiaryClass: PolymorphicBaseClass.DerivedClass {}
