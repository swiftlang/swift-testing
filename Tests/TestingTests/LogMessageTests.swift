//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) @_spi(Experimental) import Testing

@Suite(.serialized) struct `LogMessage tests` {
  @Test func `print() is logged`() async {
    var configuration = Configuration()
    configuration.eventHandler = { event, context in
      guard case let .messageLogged(message) = event.kind else {
        return
      }

      #expect(String(message.stringValue) == "Printed a message")
    }

    let handler = IssueHandlingTrait.compactMapIssues { issue in
      var issue = issue
      issue.comments.append("Bar")
      return issue
    }

    await Test(handler) {
      print("Printed a message")
    }.run(configuration: configuration)
  }
}
