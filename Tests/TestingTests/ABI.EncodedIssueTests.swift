//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

#if !SWT_NO_ABI_JSON_SCHEMA
@Suite struct `ABI.EncodedIssue Tests` {
  // MARK: - Test Helpers

  /// Creates an EncodedIssue from a JSON string.
  ///
  /// - Throws: If the JSON doesn't represent a valid EncodedIssue.
  private func encodedIssue<V>(_ version: V.Type, _ json: String) throws -> ABI.EncodedIssue<V> {
    var json = json
    return try json.withUTF8 { json in
      try JSON.decode(ABI.EncodedIssue<V>.self, from: UnsafeRawBufferPointer(json))
    }
  }

  /// Converts pretty-printed JSON -> single line JSON by trimming out
  /// indentation and newlines.
  ///
  /// This allows us to write test expectations with nicer formatting.
  private func minified(_ json: String) -> String {
    json.split(separator: "\n")
      .map { $0.trimmingPrefix { $0 == " " } }
      .joined()
  }

  static let sourceLocation = SourceLocation(fileID: "SomeTests/SomeTests.swift", filePath: "/path/to/SomeTests.swift", line: 1, column: 1)

  static let expectationFailedIssue: Issue = {
    // SourceLocation must be provided for the Issue in order for it to go from
    // Issue -> EncodedIssue -> Issue and successfully decode its expression
    var evaluatedExpression = __Expression("#expect(a == b)")
    evaluatedExpression.runtimeValue = __Expression.Value(describing: false)
    return Issue(
      kind:
        .expectationFailed(
          .init(
            evaluatedExpression: evaluatedExpression,
            isPassing: false,
            isRequired: true,
            sourceLocation: sourceLocation)
        ),
      comments: ["My User Comment"],
      sourceContext: .init(sourceLocation: sourceLocation))
  }()

  static let sampleEventContext: Event.Context = Event.Context(
    test: Test {}, testCase: nil, iteration: 1, configuration: nil)

  struct FakeError: Error {}

  // MARK: - Encode different issue types

  struct IssueEncodingTestCase: CustomTestStringConvertible {
    var testDescription: String {
      "Issue to encode: \(issueToEncode.description)"
    }

    var issueToEncode: Issue
    /// The JSON the issue should encode into. The test should minify this
    /// before comparing to the actual JSON.
    var expectedJSON: String
  }

  static let issueTestCases = [
    IssueEncodingTestCase(
      issueToEncode: Self.expectationFailedIssue,
      expectedJSON: ##"""
        {
          "expression":{
            "sourceCode":"#expect(a == b)",
            "type":{
              "fullyQualifiedName":"Swift.Bool",
              "mangledName":"$sSb",
              "unqualifiedName":"Bool"
            },
            "value":"false"
          },
          "isFailure":true,
          "severity":"error"
        }
        """##),
    IssueEncodingTestCase(
      issueToEncode: Issue(kind: .errorCaught(FakeError())),
      expectedJSON: #"""
        {
          "error":{
            "code":1,
            "description":"FakeError()",
            "domain":"TestingTests.`ABI.EncodedIssue Tests`.FakeError",
            "type":{
              "fullyQualifiedName":"TestingTests.`ABI.EncodedIssue Tests`.FakeError",
              "mangledName":"$s12TestingTests0035ABIEncodedIssueTests_wtaFABFCjAGawaV9FakeErrorV",
              "unqualifiedName":"FakeError"
            }
          },
          "isFailure":true,
          "severity":"error"
        }
        """#),
    IssueEncodingTestCase(
      issueToEncode: Issue(kind: .knownIssueNotRecorded),
      expectedJSON: #"""
        {
          "error":{
            "code":1,
            "domain":"org.swift.testing.KnownIssueNotRecordedError",
            "type":{
              "fullyQualifiedName":"Testing.KnownIssueNotRecordedError",
              "mangledName":"$s7Testing26KnownIssueNotRecordedErrorV",
              "unqualifiedName":"KnownIssueNotRecordedError"
            }
          },
          "isFailure":true,
          "severity":"error"
        }
        """#),
    IssueEncodingTestCase(
      issueToEncode: Issue(kind: .timeLimitExceeded(timeLimitComponents: (60, 0))),
      expectedJSON: #"{"exceededTimeLimit":60,"isFailure":true,"severity":"error"}"#),
    IssueEncodingTestCase(
      issueToEncode: Issue(kind: .confirmationMiscounted(actual: 5, expected: 10...10)),
      expectedJSON: #"""
        {
          "confirmationMiscount":{
            "actual":5,
            "expected":10
          },
          "isFailure":true,
          "severity":"error"
        }
        """#),
    IssueEncodingTestCase(
      issueToEncode: Issue(kind: .confirmationMiscounted(actual: 5, expected: 10...15)),
      expectedJSON: #"""
        {
          "confirmationMiscount":{
            "actual":5,
            "expected":{
              "max":15,
              "min":10
            }
          },
          "isFailure":true,
          "severity":"error"
        }
        """#),
    IssueEncodingTestCase(
      issueToEncode: {
        var issue = Issue(kind: .errorCaught(FakeError()))
        issue.knownIssueContext = .init(comment: "This issue was marked as known")
        return issue
      }(),
      expectedJSON: #"""
        {
          "error":{
            "code":1,
            "description":"FakeError()",
            "domain":"TestingTests.`ABI.EncodedIssue Tests`.FakeError",
            "type":{
              "fullyQualifiedName":"TestingTests.`ABI.EncodedIssue Tests`.FakeError",
              "mangledName":"$s12TestingTests0035ABIEncodedIssueTests_wtaFABFCjAGawaV9FakeErrorV",
              "unqualifiedName":"FakeError"
            }
          },
          "isFailure":false,
          "isKnown":"This issue was marked as known",
          "severity":"error"
        }
        """#),
    IssueEncodingTestCase(
      issueToEncode: {
        var issue = Issue(kind: .errorCaught(FakeError()))
        issue.knownIssueContext = .init()
        return issue
      }(),
      expectedJSON: #"""
        {
          "error":{
            "code":1,
            "description":"FakeError()",
            "domain":"TestingTests.`ABI.EncodedIssue Tests`.FakeError",
            "type":{
              "fullyQualifiedName":"TestingTests.`ABI.EncodedIssue Tests`.FakeError",
              "mangledName":"$s12TestingTests0035ABIEncodedIssueTests_wtaFABFCjAGawaV9FakeErrorV",
              "unqualifiedName":"FakeError"
            }
          },
          "isFailure":false,
          "isKnown":true,
          "severity":"error"
        }
        """#),
  ]

  @Test(arguments: Self.issueTestCases)
  func `Encodes issue types to expected JSON`(testCase: IssueEncodingTestCase) throws {
    let encoded = ABI.EncodedIssue<ABI.CurrentVersion>(encoding: testCase.issueToEncode, in: Self.sampleEventContext)
    try JSON.withEncoding(of: encoded) { json in
      let jsonString = String(decoding: json, as: UTF8.self)
      #expect(jsonString == minified(testCase.expectedJSON))
    }
  }

  @Test(arguments: Self.issueTestCases)
  func `Issue -> EncodedEvent -> Issue preserves issue kind, comments, and source location`(testCase: IssueEncodingTestCase) throws {
    var issue = testCase.issueToEncode
    issue.comments = ["Some User Comment"]
    issue.sourceContext = .init(sourceLocation: Self.sourceLocation)
    let encoded = try #require(ABI.EncodedEvent<ABI.CurrentVersion>(encoding: .init(.issueRecorded(issue), testID: nil, testCaseID: nil),  in: Self.sampleEventContext))
    let decodedIssue = try #require(Issue(decoding: encoded))

    // Using the Issue.Kind description as a workaround to compare two values
    // that are enums with associated values
    #expect(testCase.issueToEncode.kind.description == decodedIssue.kind.description)
    #expect(decodedIssue.sourceLocation != nil)
    #expect(!decodedIssue.comments.isEmpty)
  }

  // MARK: - Backwards compatibility

  @Test func `Decodes v6.4 JSON`() throws {
    _ = try encodedIssue(
      ABI.v6_4.self,
      """
      {
        "isKnown": false,
        "severity": "error",
        "isFailure": true,
      }
      """
    )
  }

  @Test func `Fails to decode v6.4 with missing isKnown field`() throws {
    #expect(throws: DecodingError.self) {
      _ = try encodedIssue(
        ABI.v6_4.self,
        """
        {
          "severity": "error",
          "isFailure": true,
        }
        """
      )
    }
  }

  /// isKnown became optional in 6.5
  @Test func `Decodes current ABI with missing isKnown field`() throws {
    #expect(throws: Never.self) {
      _ = try encodedIssue(
        ABI.CurrentVersion.self,
        """
        {
          "severity": "error",
          "isFailure": true,
        }
        """
      )
    }
  }

  /// Each of these issue kinds contain extra information that is only encoded
  /// in v6.5 of the issue, so they should all encode to the same JSON in v6.4.
  /// sourceLocation is also removed in v6.5, but needs to stay for v6.4.
  @Test(arguments: [
    Self.expectationFailedIssue,
    Issue(kind: .errorCaught(FakeError()), sourceContext: .init(sourceLocation: Self.sourceLocation)),
    Issue(kind: .knownIssueNotRecorded, sourceContext: .init(sourceLocation: Self.sourceLocation)),
    Issue(kind: .timeLimitExceeded(timeLimitComponents: (60, 0)), sourceContext: .init(sourceLocation: Self.sourceLocation)),
    Issue(kind: .confirmationMiscounted(actual: 5, expected: 10...10), sourceContext: .init(sourceLocation: Self.sourceLocation)),
  ])
  func `Maintains original encoding for v6.4 issues`(issue: Issue) throws {
    let encoded = ABI.EncodedIssue<ABI.v6_4>(encoding: issue, in: Self.sampleEventContext)
    try JSON.withEncoding(of: encoded) { json in
      let jsonString = String(decoding: json, as: UTF8.self)

      #expect(jsonString == minified(#"""
        {
          "isFailure":true,
          "isKnown":false,
          "severity":"error",
          "sourceLocation":{
            "column":1,
            "fileID":"SomeTests\/SomeTests.swift",
            "filePath":"\/path\/to\/SomeTests.swift",
            "line":1
          }
        }
        """#)
      )
    }
  }

  @Test func `Encodes v6.4 known issue without including comment`() throws {
    let encoded = {
      var issue = Issue(kind: .errorCaught(FakeError()))
      issue.knownIssueContext = .init(comment: "This issue was marked as known")
      return ABI.EncodedIssue<ABI.v6_4>(encoding: issue, in: Self.sampleEventContext)
    }()
    try JSON.withEncoding(of: encoded) { json in
      let jsonString = String(decoding: json, as: UTF8.self)

      #expect(jsonString == #"{"isFailure":false,"isKnown":true,"severity":"error"}"#)
    }
  }
}
#endif
