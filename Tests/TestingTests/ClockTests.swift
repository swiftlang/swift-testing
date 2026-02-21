//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

private import _TestingInternals

@Suite("Clock API Tests")
struct ClockTests {
  @Test("Clock.Instant basics")
  func clockInstant() async throws {
    let instant1 = Test.Clock.Instant.now
    try await Test.Clock.sleep(for: .nanoseconds(50_000_000))
    let instant2 = Test.Clock.Instant.now

    #expect(instant1 == instant1)
    #expect(instant1 < instant2)
    #expect(!(instant2 < instant1))
    #expect(instant2 > instant1)

    let instant3 = instant2.advanced(by: .seconds(5))
    #expect(instant2 < instant3)
    #expect(!(instant3 < instant2))
    #expect(instant3 > instant2)

    // Exercise the hash function.
    let instants = Set([instant1, instant1, instant2])
    #expect(instants.count == 2)

    let now = Test.Clock.Instant.now
    #expect(now.suspending.seconds > 0)
    #expect(now.suspending.attoseconds >= 0)
#if !SWT_NO_UTC_CLOCK
    #expect(now.wall.seconds > 0)
    #expect(now.wall.attoseconds >= 0)
#endif
  }

  @Test("Creating a SuspendingClock.Instant from Test.Clock.Instant")
  func suspendingInstantInitializer() async throws {
    let instant1 = SuspendingClock.Instant(Test.Clock.Instant.now)
    try await Test.Clock.sleep(for: .milliseconds(50))
    let instant2 = SuspendingClock.Instant(Test.Clock.Instant.now)

    #expect(instant1 < instant2)
  }

  @Test("Clock.sleep(until:tolerance:) method")
  func sleepUntilTolerance() async throws {
    let instant1 = SuspendingClock.Instant(Test.Clock.Instant.now)
    try await Test.Clock().sleep(until: .now.advanced(by: .milliseconds(50)), tolerance: nil)
    let instant2 = SuspendingClock.Instant(Test.Clock.Instant.now)

    #expect(instant1 < instant2)
  }

#if !SWT_NO_UTC_CLOCK
  @Test("Clock.Instant.timeComponentsSince1970 property")
  func timeComponentsSince1970() async throws {
    let instant1 = Test.Clock.Instant.now.timeComponentsSince1970
    try await Test.Clock.sleep(for: .nanoseconds(50_000_000))
    let instant2 = Test.Clock.Instant.now.timeComponentsSince1970

    #expect(instant1.seconds < instant2.seconds || instant1.attoseconds < instant2.attoseconds)
  }
#endif

#if !SWT_NO_UTC_CLOCK
  @Test("Clock.Instant.durationSince1970 property")
  func durationSince1970() async throws {
    let instant1 = Test.Clock.Instant.now.durationSince1970
    try await Test.Clock.sleep(for: .milliseconds(50))
    let instant2 = Test.Clock.Instant.now.durationSince1970

    #expect(instant1 < instant2)
  }
#endif

  @Test("Clock.now property")
  func clockNowProperty() async throws {
    let instant1 = Test.Clock().now
    try await Test.Clock.sleep(for: .milliseconds(50))
    let instant2 = Test.Clock().now

    #expect(instant1 < instant2)
  }

  @Test("Clock.minimumResolution property")
  func clockMinimumResolutionProperty() async throws {
    let minimumResolution = Test.Clock().minimumResolution
    #expect(minimumResolution == SuspendingClock().minimumResolution)
  }

  @Test("Clock.Instant.advanced(by:) and .duration(to:) methods")
  func instantAdvancedByAndDurationTo() async throws {
    let offsetNanoseconds = Int64.random(in: -1_000_000_000 ..< 1_000_000_000)

    let instant1 = Test.Clock.Instant.now
    let instant2 = instant1.advanced(by: .nanoseconds(offsetNanoseconds))
    let duration = instant1.duration(to: instant2)

    #expect(SuspendingClock.Instant(instant1).advanced(by: .nanoseconds(offsetNanoseconds)) == SuspendingClock.Instant(instant2))
#if !SWT_NO_UTC_CLOCK
    #expect(instant1.durationSince1970 + .nanoseconds(offsetNanoseconds) == instant2.durationSince1970)
#endif
    #expect(duration == .nanoseconds(offsetNanoseconds))
  }

#if canImport(Foundation)
  @Test("Codable")
  func codable() async throws {
    let now = Test.Clock.Instant()
    let instant = now.advanced(by: .nanoseconds(100))
    let decoded = try JSON.encodeAndDecode(instant)
    #expect(instant == decoded)
    #expect(instant != now)
  }
#endif

  @Test("Clock.Instant.nanoseconds(until:) method",
    arguments: [
      (Duration.zero, 0),
      (.nanoseconds(1), 1),
      (.seconds(1), 1_000_000_000),
      (Duration(secondsComponent: 0, attosecondsComponent: 1), 0),
    ]
  )
  func nanoseconds(until offset: Duration, nanoseconds: Int) {
    let now = Test.Clock.Instant.now
    #expect(now.nanoseconds(until: now.advanced(by: offset)) == nanoseconds)
  }
}
