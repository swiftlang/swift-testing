//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE // other platforms use Synchronization
@testable import Testing

final class `Mutex tests`: Sendable {
  let lock = Mutex(0)

  @Test func `Locking and unlocking`() {
    #expect(lock.rawValue == 0)
    lock.withLock { value in
      value = 1
    }
    #expect(lock.rawValue == 1)
  }

  @Test func `Repeatedly accessing a lock`() async {
    await withTaskGroup { taskGroup in
      for _ in 0 ..< 100_000 {
        taskGroup.addTask {
          self.lock.withLock { $0 += 1 }
        }
      }
    }
    #expect(lock.rawValue == 100_000)
  }
}
#endif
