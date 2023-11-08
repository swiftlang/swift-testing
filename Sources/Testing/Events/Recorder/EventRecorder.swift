//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ExperimentalEventHandling)
public protocol EventRecorder: Sendable {
  /// Record the specified event by generating a representation of it in this
  /// instance's output format and writing it to this instance's destination.
  ///
  /// - Parameters:
  ///   - event: The event to record.
  ///   - context: The context associated with the event.
  ///
  /// - Returns: Whether any output was produced and written to this instance's
  ///   destination.
  func record(_ event: borrowing Event, in context: borrowing Event.Context) -> Bool
}
