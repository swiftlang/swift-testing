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
import Testing

@c func swift_createDefaultExecutorsOnce() {}
@c func _swift_willThrow() {}

/// The main entry point for tests running under Embedded Swift.
@main struct EmbeddedSwiftEntryPoint {
  static func main() {
    listAllTests()
  }
}
#endif
