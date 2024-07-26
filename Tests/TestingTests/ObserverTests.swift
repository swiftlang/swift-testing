//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) import Testing

@Observer final class ExampleObserver: Sendable {
  func observe(_ event: borrowing Event, in context: borrowing Event.Context) {
    switch event.kind {
    case let .issueRecorded(issue):
      let test = context.test
      let testName = String(describingForTest: test?.displayName ?? test?.name)
      print("Oh no! An issue occurred in \(testName): \(issue)")
    case .runEnded:
      print("Bye bye!")
    default:
      break
    }
  }
}
