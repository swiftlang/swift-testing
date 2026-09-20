//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Testing

@export(interface) @c func main(_ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>>, argc: CInt) -> CInt {
#if !hasFeature(Embedded)
  fatalError("This target is intended for Embedded Swift only.")
#else
  swift_testing_embeddedMain(argv, argc)
#endif
}
