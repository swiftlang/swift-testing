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
  ///   - backtrace: The backtrace associated with the new instance.
  ///   - sourceLocation: The source location associated with the new instance,
  ///     if available.
  public init(backtrace: Backtrace?, sourceLocation: SourceLocation?) {
    self.backtrace = backtrace
    self.sourceLocation = sourceLocation
  }
}

extension SourceContext: Equatable, Hashable {}

// MARK: - Codable

extension SourceContext: Codable {}

// MARK: - Deprecated

extension SourceContext {
  @available(*, deprecated, message: "Use init(backtrace:sourceLocation:) and pass both arguments explicitly instead.")
  public init(backtrace: Backtrace?) {
    self.init(backtrace: backtrace, sourceLocation: nil)
  }

  @available(*, deprecated, message: "Use init(backtrace:sourceLocation:) and pass both arguments explicitly instead.")
  public init(sourceLocation: SourceLocation? = nil) {
    self.init(backtrace: nil, sourceLocation: sourceLocation)
  }
}
