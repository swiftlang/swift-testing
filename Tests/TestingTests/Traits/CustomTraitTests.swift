//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

// Note: Do NOT include `@_spi` on this import. The contents of this file are
// specifically intended to validate that a type conforming to `TestTrait` can
// be declared without importing anything except the base.
import Testing

// This is a "build-only" test which simply validates that we can successfully
// declare a type conforming to `TestTrait` and use its default implementations.
struct MyCustomTrait: TestTrait {}
