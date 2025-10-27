//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing

#if !hasFeature(NonisolatedNonsendingByDefault)
#error("This file requires nonisolated(nonsending)-by-default to be enabled")
#endif

#if !SWT_NO_EXIT_TESTS
@Test func `exit test with nonisolated(nonsending)`() async {
  await #expect(processExitsWith: .success) {}
}
#endif
