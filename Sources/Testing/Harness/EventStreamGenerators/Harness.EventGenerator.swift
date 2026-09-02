//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Harness {
  /// A protocol describing types that can generate events for the harness to
  /// handle.
  ///
  /// Instances of conforming types may be copied a large number of times, so
  /// such types must be classes to reduce memory usage.
  package protocol EventGenerator: Sendable, AnyObject {
    /// A human-readable name for this instance.
    ///
    /// The testing harness presents the value of this property to users when
    /// running it.
    var humanReadableName: String { get }

    /// Run this generator.
    ///
    /// - Parameters:
    ///   - eventHandler: An event handler function to invoke for each event
    ///     that this generator generates.
    ///
    /// - Throws: Any error that prevents generating further events.
    ///
    /// Implementations should use this function to transform whatever their
    /// inputs may be into testing library events. The function should run until
    /// all its events have been generated, then return normally.
    func run(_ eventHandler: @Sendable (borrowing Event, borrowing Event.Context) async throws -> Void) async throws
  }
}
