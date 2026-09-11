//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if hasFeature(Embedded)
import _Concurrency

/// The main entry point for tests running under Embedded Swift.
@main struct EmbeddedSwiftEntryPoint {
  static func main() async {
    let exitCode: CInt = await entryPoint(passing: nil, eventHandler: nil)
    exit(exitCode)
  }
}
#endif
