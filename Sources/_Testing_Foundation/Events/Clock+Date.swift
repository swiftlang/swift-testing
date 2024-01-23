//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation) && !SWT_NO_UTC_CLOCK
@_spi(ExperimentalEventHandling) public import Testing
public import Foundation

extension Date {
  /// Initialize this date to the equivalent of the same date on the testing
  /// library's clock.
  ///
  /// - Parameters:
  ///   - testClockInstant: The equivalent instant on ``Test/Clock``.
  ///
  /// The resulting instance is equivalent to the wall-clock time represented by
  /// `testClockInstant`. For precise date/time calculations, convert instances
  /// of ``Test/Clock/Instant`` to `SuspendingClock.Instant` instead of `Date`.
  @_spi(ExperimentalEventHandling)
  public init(_ testClockInstant: Test.Clock.Instant) {
    let components = testClockInstant.timeComponentsSince1970
    let secondsSince1970 = TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / TimeInterval(1_000_000_000_000_000_000))
    self.init(timeIntervalSince1970: secondsSince1970)
  }
}
#endif
