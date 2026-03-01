//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE // other platforms use Synchronization
@testable import Testing

final class `Atomic tests`: Sendable {
  let atomicValue = Atomic(0)

  @Test func `Loading and storing`() {
    #expect(atomicValue.load(ordering: .sequentiallyConsistent) == 0)
    atomicValue.store(1, ordering: .sequentiallyConsistent)
    #expect(atomicValue.load(ordering: .sequentiallyConsistent) == 1)
  }

  @Test func `Repeatedly incrementing an atomic value`() async {
    await withTaskGroup { taskGroup in
      for _ in 0 ..< 100_000 {
        taskGroup.addTask {
          self.atomicValue.add(1, ordering: .sequentiallyConsistent)
        }
      }
    }
    #expect(atomicValue.load(ordering: .sequentiallyConsistent) == 100_000)
  }
}
#endif
