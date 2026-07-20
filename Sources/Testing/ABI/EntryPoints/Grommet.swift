//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

// FIXME: need an actual name for this protocol
package protocol Grommet: Sendable {
  var grommetName: String { get }
  func run(_ eventHandler: @escaping @Sendable (borrowing Event, borrowing Event.Context) -> Void) async throws
}

extension Runner: Grommet {
  package var grommetName: String {
    ""
  }

  package func run(_ eventHandler: @escaping @Sendable (borrowing Event, borrowing Event.Context) -> Void) async throws {
    var selfCopy = self
    selfCopy.configuration.eventHandler = { [oldEventHandler = selfCopy.configuration.eventHandler] event, context in
      eventHandler(event, context)
      oldEventHandler(event, context)
    }
    await selfCopy.run()
  }
}
