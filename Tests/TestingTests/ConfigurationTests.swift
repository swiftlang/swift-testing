//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ForToolsIntegrationOnly) import Testing

@Suite("Configuration Tests")
struct ConfigurationTests {
  @Test
  @available(*, deprecated, message: "Testing a deprecated SPI.")
  func deliverExpectationCheckedEventsProperty() throws {
    var configuration = Configuration()
    #expect(!configuration.deliverExpectationCheckedEvents)
    #expect(!configuration.eventHandlingOptions.isExpectationCheckedEventEnabled)

    configuration.deliverExpectationCheckedEvents = true
    #expect(configuration.eventHandlingOptions.isExpectationCheckedEventEnabled)
  }
}
