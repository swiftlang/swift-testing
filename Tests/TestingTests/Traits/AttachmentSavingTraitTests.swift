//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

struct `Attachment.ConditionalRecordingTrait tests` {
  func runRecordingAttachmentTests(with trait: AttachmentSavingTrait?, expectedCount: Int, expectedIssueCount: Int = Self.issueCountFromTestBodies, expectedPreferredName: String?) async throws {
    let traitToApply = trait as (any SuiteTrait)? ?? Self.currentRecordingAttachmentsTrait
    try await Self.$currentRecordingAttachmentsTrait.withValue(traitToApply) {
      try await confirmation("Issue recorded", expectedCount: expectedIssueCount) { issueRecorded in
        try await confirmation("Attachment detected", expectedCount: expectedCount) { valueAttached in
          var configuration = Configuration()
          configuration.attachmentsPath = try temporaryDirectory()
          configuration.eventHandler = { event, _ in
            switch event.kind {
            case .issueRecorded:
              issueRecorded()
            case let .valueAttached(attachment):
              if trait != nil {
                #expect(event.wasDeferred)
              }
              if let expectedPreferredName {
                #expect(attachment.preferredName == expectedPreferredName)
              }
              valueAttached()
            default:
              break
            }
          }

          await runTest(for: FixtureSuite.self, configuration: configuration)
        }
      }
    }
  }

  @Test func `Recording attachments without conditions`() async throws {
    try await runRecordingAttachmentTests(
      with: nil,
      expectedCount: Self.totalTestCaseCount,
      expectedPreferredName: nil
    )
  }

  @Test func `Recording attachments only on test pass`() async throws {
    try await runRecordingAttachmentTests(
      with: .savingAttachments(if: .testPasses),
      expectedCount: Self.passingTestCaseCount,
      expectedPreferredName: "PASSING TEST"
    )
  }

  @Test func `Recording attachments only on test failure`() async throws {
    try await runRecordingAttachmentTests(
      with: .savingAttachments(if: .testFails),
      expectedCount: Self.failingTestCaseCount,
      expectedPreferredName: "FAILING TEST"
    )
  }

  @Test func `Recording attachments with custom condition`() async throws {
    try await runRecordingAttachmentTests(
      with: .savingAttachments(if: true),
      expectedCount: Self.totalTestCaseCount,
      expectedPreferredName: nil
    )

    try await runRecordingAttachmentTests(
      with: .savingAttachments(if: false),
      expectedCount: 0,
      expectedPreferredName: nil
    )
  }

  @Test func `Recording attachments with custom async condition`() async throws {
    @Sendable func conditionFunction() async -> Bool {
      true
    }

    try await runRecordingAttachmentTests(
      with: .savingAttachments(if: conditionFunction),
      expectedCount: Self.totalTestCaseCount,
      expectedPreferredName: nil
    )
  }

  @Test func `Recording attachments but the condition throws`() async throws {
    @Sendable func conditionFunction() throws -> Bool {
      throw MyError()
    }

    try await runRecordingAttachmentTests(
      with: .savingAttachments(if: conditionFunction),
      expectedCount: 0,
      expectedIssueCount: Self.issueCountFromTestBodies + Self.totalTestCaseCount /* thrown from conditionFunction */,
      expectedPreferredName: nil
    )
  }
}

// MARK: - Fixtures

extension `Attachment.ConditionalRecordingTrait tests` {
  static let totalTestCaseCount = 1 + 1 + 5 + 7
  static let passingTestCaseCount = 1 + 5
  static let failingTestCaseCount = 1 + 7
  static let issueCountFromTestBodies = failingTestCaseCount

  @TaskLocal
  static var currentRecordingAttachmentsTrait: any SuiteTrait = Comment(rawValue: "<no .recordingAttachments trait set>")

  @Suite(.hidden, currentRecordingAttachmentsTrait)
  struct FixtureSuite {
    @Test(.hidden) func `Records an attachment (passing)`() {
      Attachment.record("", named: "PASSING TEST")
    }

    @Test(.hidden) func `Records an attachment (failing)`() {
      Attachment.record("", named: "FAILING TEST")
      Issue.record("")
    }

    @Test(.hidden, arguments: 0 ..< 5)
    func `Records an attachment (passing, parameterized)`(i: Int) async {
      Attachment.record("\(i)", named: "PASSING TEST")
    }

    @Test(.hidden, arguments: 0 ..< 7) // intentionally different count
    func `Records an attachment (failing, parameterized)`(i: Int) async {
      Attachment.record("\(i)", named: "FAILING TEST")
      Issue.record("\(i)")
    }
  }
}

