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
@_spi(Experimental) @_spi(ForToolsIntegrationOnly) public import Testing
public import Foundation

@_spi(ForToolsIntegrationOnly)
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
  public init(_ testClockInstant: Test.Clock.Instant) {
    let components = testClockInstant.timeComponentsSince1970
    let secondsSince1970 = TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / TimeInterval(1_000_000_000_000_000_000))
    self.init(timeIntervalSince1970: secondsSince1970)
  }

  /// Initialize this date to equal an instant from the testing library's event
  /// stream.
  ///
  /// - Parameters:
  ///   - encodedInstant: The equivalent instant.
  ///
  /// The resulting instance is equivalent to the wall-clock time represented by
  /// `encodedInstant`. For precise date/time calculations, convert instances
  /// of ``ABI/EncodedInstant`` to `SuspendingClock.Instant` instead of `Date`.
  public init(_ encodedInstant: ABI.EncodedInstant<some ABI.Version>) {
    self.init(timeIntervalSince1970: encodedInstant.since1970)
  }
}
#endif
