//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalTestRunning) @_spi(ForToolsIntegrationOnly) import Testing

#if canImport(Foundation)
import Foundation
#endif

@Suite("Runner.Plan.Snapshot tests")
struct Runner_Plan_SnapshotTests {
#if canImport(Foundation)
  @Test("Codable")
  func codable() async throws {
    let suite = try #require(await test(for: Runner_Plan_SnapshotFixtures.self))

    var configuration = Configuration()
    configuration.setTestFilter(toInclude: [suite.id], includeHiddenTests: true)

    let plan = await Runner.Plan(configuration: configuration)
    let snapshot = Runner.Plan.Snapshot(snapshotting: plan)
    let decoded = try JSONDecoder().decode(Runner.Plan.Snapshot.self, from: JSONEncoder().encode(snapshot))

    try #require(decoded.steps.count == snapshot.steps.count)

    func sort(_ lhs: Runner.Plan.Step.Snapshot, _ rhs: Runner.Plan.Step.Snapshot) -> Bool {
      String(describing: lhs.test.id) < String(describing: rhs.test.id)
    }

    for (decodedStep, snapshotStep) in zip(decoded.steps.sorted(by: sort), snapshot.steps.sorted(by: sort)) {
      #expect(decodedStep.test.id == snapshotStep.test.id)

      switch (decodedStep.action, snapshotStep.action) {
      case (.run, .run):
        break
      case let (.skip(decodedSkipInfo), .skip(snapshotSkipInfo)):
        #expect(decodedSkipInfo == snapshotSkipInfo)
      case let (.recordIssue(decodedIssue), .recordIssue(snapshotIssue)):
        #expect(String(describing: decodedIssue) == String(describing: snapshotIssue))
      default:
        Issue.record("Decoded step does not match the original snapshotted step: decodedStep: \(decodedStep), snapshotStep: \(snapshotStep)")
      }
    }
  }
#endif
}

// MARK: - Fixture tests

@Suite(.hidden)
private struct Runner_Plan_SnapshotFixtures {
  @Test(.hidden)
  func basicTest() {}

  @Test(.hidden, .disabled("To validate skip action"))
  func disabledTest() {}

  private static func _erroneousCondition() throws -> Bool {
    struct ContrivedError: Error {}
    throw ContrivedError()
  }

  @Test(.hidden, .enabled(if: try _erroneousCondition(), "To demonstrate recordIssue action"))
  func erroneousTest() {}
}
