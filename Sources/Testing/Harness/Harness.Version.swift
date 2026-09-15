//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Harness {
  /// The JSON schema version the harness uses by default.
  ///
  /// The harness is able to decode record JSON of any supported schema version,
  /// but uses this version by default.
  package typealias Version = ABI.ExperimentalVersion
}
