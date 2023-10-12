//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Foundation
@testable @_spi(ExperimentalEventHandling) import Testing
@_implementationOnly import TestingInternals

@Suite("Clock API Tests")
struct ClockTests {
  @available(_clockAPI, *)
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

#if SWT_TARGET_OS_APPLE
    #expect(Test.Clock.Instant.now.uptime.tv_sec > 0)
    #expect(Test.Clock.Instant.now.uptime.tv_nsec >= 0)
#endif
#if !SWT_NO_UTC_CLOCK
    #expect(Test.Clock.Instant.now.nanosecondsSince1970 > 0)
#endif
  }

  @available(_clockAPI, *)
  @Test("Creating a SuspendingClock.Instant from Test.Clock.Instant")
  func suspendingInstantInitializer() async throws {
    let instant1 = SuspendingClock.Instant(Test.Clock.Instant.now)
    try await Test.Clock.sleep(for: .milliseconds(50))
    let instant2 = SuspendingClock.Instant(Test.Clock.Instant.now)

    #expect(instant1 < instant2)
  }

  @available(_clockAPI, *)
  @Test("Clock.sleep(until:tolerance:) method")
  func sleepUntilTolerance() async throws {
    let instant1 = SuspendingClock.Instant(Test.Clock.Instant.now)
    try await Test.Clock().sleep(until: .now.advanced(by: .milliseconds(50)), tolerance: nil)
    let instant2 = SuspendingClock.Instant(Test.Clock.Instant.now)

    #expect(instant1 < instant2)
  }

#if !SWT_NO_UTC_CLOCK
  @available(_clockAPI, *)
  @Test("Clock.Instant.nanosecondsSince1970 property")
  func nanosecondsSince1970() async throws {
    let instant1 = Test.Clock.Instant.now.nanosecondsSince1970
    try await Test.Clock.sleep(for: .nanoseconds(50_000_000))
    let instant2 = Test.Clock.Instant.now.nanosecondsSince1970

    #expect(instant1 < instant2)
  }
#endif

#if !SWT_NO_UTC_CLOCK
  @available(_clockAPI, *)
  @Test("Clock.Instant.durationSince1970 property")
  func durationSince1970() async throws {
    let instant1 = Test.Clock.Instant.now.durationSince1970
    try await Test.Clock.sleep(for: .milliseconds(50))
    let instant2 = Test.Clock.Instant.now.durationSince1970

    #expect(instant1 < instant2)
  }
#endif

  @available(_clockAPI, *)
  @Test("Clock.now property")
  func clockNowProperty() async throws {
    let instant1 = Test.Clock().now
    try await Test.Clock.sleep(for: .milliseconds(50))
    let instant2 = Test.Clock().now

    #expect(instant1 < instant2)
  }

  @available(_clockAPI, *)
  @Test("Clock.minimumResolution property")
  func clockMinimumResolutionProperty() async throws {
    let minimumResolution = Test.Clock().minimumResolution
    #expect(minimumResolution == SuspendingClock().minimumResolution)
  }

  @available(_clockAPI, *)
  @Test("Clock.Instant.advanced(by:) and .duration(to:) methods")
  func instantAdvancedByAndDurationTo() async throws {
    let offsetNanoseconds = Int64.random(in: -1_000_000_000 ..< 1_000_000_000)

    let instant1 = Test.Clock.Instant.now
    let instant2 = instant1.advanced(by: .nanoseconds(offsetNanoseconds))
    let duration = instant1.duration(to: instant2)

    #expect(SuspendingClock.Instant(instant1).advanced(by: .nanoseconds(offsetNanoseconds)) == SuspendingClock.Instant(instant2))
#if !SWT_NO_UTC_CLOCK
    #expect(instant1.nanosecondsSince1970 + offsetNanoseconds == instant2.nanosecondsSince1970)
#endif
    #expect(duration == .nanoseconds(offsetNanoseconds))
  }

  @available(_clockAPI, *)
  @Test("Codable")
  func codable() async throws {
    let instant = Test.Clock.Instant().advanced(by: .nanoseconds(100))
    let decoded = try JSONDecoder().decode(Test.Clock.Instant.self,
                                           from: JSONEncoder().encode(instant))

    #expect(instant == decoded)
    #expect(instant != Test.Clock.Instant())
  }
}
