//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

public import Testing

extension Issue {
  /// Record this issue to the testing Library.
  ///
  /// - Returns: The issue that was recorded (`self` or a modified copy of it.)
  public func record() -> Self {
    self.record(configuration: nil)
  }
}
