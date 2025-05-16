//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing the behavior to use while polling.
@_spi(Experimental)
@frozen public enum PollingBehavior {
  /// Continuously evaluate the expression until the first time it returns
  /// true.
  /// If it does not pass once by the time the timeout is reached, then a
  /// failure will be reported.
  case passesOnce

  /// Continuously evaluate the expression until the first time it returns
  /// false.
  /// If the expression returns false, then a failure will be reported.
  /// If the expression only returns true before the timeout is reached, then
  /// no failure will be reported.
  /// If the expression does not finish evaluating before the timeout is
  /// reached, then a failure will be reported.
  case passesAlways
}
