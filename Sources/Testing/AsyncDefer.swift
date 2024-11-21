//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

struct AsyncDefer: Sendable {
  var sourceLocation: SourceLocation
  var body: @Sendable () async throws -> Void
}

extension AsyncDefer {
  struct Group: Sendable {
    private var _asyncDefers = Locked<[AsyncDefer]>(rawValue: [])

    func runAll() async {
      for asyncDefer in _asyncDefers.rawValue.reversed() {
        await Issue.withErrorRecording(at: asyncDefer.sourceLocation, asyncDefer.body)
      }
    }

    public func add(at sourceLocation: SourceLocation, _ body: @escaping @Sendable () async -> Void) async {
      _asyncDefers.withLock { asyncDefers in
        let asyncDefer = AsyncDefer(sourceLocation: sourceLocation, body: body)
        asyncDefers.append(asyncDefer)
      }
    }
  }
}
