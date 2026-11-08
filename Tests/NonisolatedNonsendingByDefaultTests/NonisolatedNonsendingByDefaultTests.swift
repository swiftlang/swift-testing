//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing

#if !hasFeature(NonisolatedNonsendingByDefault)
#error("This file requires that Approachable Concurrency be enabled")
#endif

struct `Tests run with Approachable Concurrency enabled` {
  @Test func sync() {}
  @Test func `async`() async {}
  @Test nonisolated(nonsending) func `nonisolated(nonsending)`() async {}
  @Test @concurrent func `@concurrent`() async {}
}
