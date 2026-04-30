//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension String {
#if hasFeature(Embedded)
  // WORKAROUND: https://github.com/swiftlang/swift/pull/88738
  init(describing value: some CustomStringConvertible) {
    self = value.description
  }

  init(describing value: some TextOutputStreamable) {
    self.init()
    value.write(to: &self)
  }

  // WORKAROUND: https://github.com/swiftlang/swift/issues/88756
  func contains(_ other: some StringProtocol) -> Bool {
    self.indices.contains { self[$0...].hasPrefix(other) }
  }
#endif
}
