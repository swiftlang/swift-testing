//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Event {
  /// A protocol describing types that can generate event streams.
  package protocol Adapter: Sendable {
    /// A human-readable name for this instance.
    ///
    /// The testing harness presents the value of this property to users when
    /// running it.
    var adapterName: String { get }

    /// Run this adapter.
    ///
    /// - Parameters:
    ///   - eventHandler: An event handler function to invoke for each event
    ///     that the adapter generates.
    ///
    /// - Throws: Any error that prevents generating further events.
    ///
    /// Implementations should use this function to transform whatever their
    /// inputs may be into testing library events. The function should run until
    /// all its events have been generated, then return normally.
    func run(_ eventHandler: @escaping @Sendable (borrowing Event, borrowing Event.Context) async throws -> Void) async throws
  }
}
