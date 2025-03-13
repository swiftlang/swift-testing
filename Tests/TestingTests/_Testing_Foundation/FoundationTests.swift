//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_FOUNDATION && canImport(Foundation) && !SWT_NO_UTC_CLOCK
@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import _Testing_Foundation
@_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
import Foundation

struct FoundationTests {
  @Test("Casting Test.Clock.Instant to Date")
  func castTestClockInstantToDate() {
    let instant = Test.Clock.Instant.now
    let date = Date(instant)
    #expect(TimeInterval(instant.timeComponentsSince1970.seconds) == date.timeIntervalSince1970.rounded(.down))
  }
}
#endif
