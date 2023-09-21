//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalTestRunning) import Testing

@Suite("Configuration Tests")
struct ConfigurationTests {
  static var environmentVariables: [(String, UncheckedSendable<KeyPath<Configuration, Bool>>)] {
    var result: [(String, KeyPath<Configuration, Bool>)] = [
      ("SWT_ENABLE_PARALLELIZATION", \.isParallelizationEnabled),
    ]
#if !SWT_NO_GLOBAL_ACTORS
    result.append(("SWT_MAIN_ACTOR_ISOLATED", \.isMainActorIsolationEnforced))
#endif

    return result.map { ($0.0, UncheckedSendable(rawValue: $0.1)) }
  }

  @Test("Test boolean properties with environment variables",
    .bug("rdar://75861003"), // KeyPath does not conform to Sendable
    arguments: environmentVariables,
      [
        (true, "1"), (false, "0"),
        (true, String(describing: UInt64.max)), (true, String(describing: Int64.min)),
        (true, "true"), (true, "TRUE"), (true, "yes"), (true, "YES"),
        (false, "false"), (false, "FALSE"), (false, "no"), (false, "NO"),
      ]
  )
  func booleanProperty(
    environmentVariable: (name: String, keyPath: UncheckedSendable<KeyPath<Configuration, Bool>>),
    value: (expectedValue: Bool, stringValue: String)
  ) throws {
    let name = environmentVariable.0
    let keyPath = environmentVariable.1.rawValue
    let (expectedValue, stringValue) = value

    let oldEnvvar = Environment.variable(named: name)
    defer {
      Environment.setVariable(oldEnvvar, named: name)
    }
    #expect(Environment.setVariable(stringValue, named: name))

    #expect(Configuration()[keyPath: keyPath] == expectedValue)
  }
}
