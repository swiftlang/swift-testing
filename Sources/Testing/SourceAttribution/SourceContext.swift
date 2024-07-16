//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing the call stack backtrace and source location of a
/// particular call.
///
/// Most commonly used when recording a failure, in order to indicate the source
/// location where the failure occurred as well as the backtrace of the failing
/// call, since the latter may be useful to understand how it was invoked.
@_spi(ForToolsIntegrationOnly)
public struct SourceContext: Sendable {
  /// The backtrace associated with this instance, if available.
  public var backtrace: Backtrace?

  /// The location in source code associated with this instance, if available.
  public var sourceLocation: SourceLocation?

  /// Initialize an instance of this type with the specified backtrace and
  /// source location.
  ///
  /// - Parameters:
  ///   - backtrace: The backtrace associated with the new instance. Defaults to
  ///     the current backtrace (obtained via
  ///     ``Backtrace/current(maximumAddressCount:)``).
  ///   - sourceLocation: The source location associated with the new instance.
  public init(backtrace: Backtrace? = .current(), sourceLocation: SourceLocation? = nil) {
    self.backtrace = backtrace
    self.sourceLocation = sourceLocation
  }
}

extension SourceContext: Equatable, Hashable {}

// MARK: - Codable

extension SourceContext: Codable {}
