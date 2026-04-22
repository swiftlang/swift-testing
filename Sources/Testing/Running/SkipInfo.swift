//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing the details of a skipped test.
@_spi(ForToolsIntegrationOnly)
public struct SkipInfo: Sendable {
  /// A user-specified comment describing this skip, if any.
  public var comment: Comment?

  /// A source context indicating where this skip occurred.
  public var sourceContext: SourceContext

  /// The location in source where this skip occurred, if available.
  public var sourceLocation: SourceLocation? {
    get {
      sourceContext.sourceLocation
    }
    set {
      sourceContext.sourceLocation = newValue
    }
  }

  /// Initialize an instance of this type with the specified details.
  ///
  /// - Parameters:
  ///   - comment: A user-specified comment describing this skip, if any.
  ///     Defaults to `nil`.
  ///   - sourceContext: A source context indicating where this skip occurred.
  public init(
    comment: Comment? = nil,
    sourceContext: SourceContext
  ) {
    self.comment = comment
    self.sourceContext = sourceContext
  }
}

// This conforms to `Error` because throwing an instance of this type is how a
// custom trait can signal that the test it is attached to should be skipped.
extension SkipInfo: Error {}

// MARK: - Equatable, Hashable

extension SkipInfo: Equatable, Hashable {}

// MARK: - Codable

extension SkipInfo: Codable {}

// MARK: -

extension SkipInfo {
  /// Initialize an instance of this type from an arbitrary error.
  ///
  /// - Parameters:
  ///   - error: The error to convert to an instance of this type.
  ///
  /// If `error` does not represent a skip or cancellation event, this
  /// initializer returns `nil`.
  init?(_ error: any Error) {
    if let skipInfo = error as? Self {
      self = skipInfo
    } else if error is CancellationError, Task.isCancelled {
      // Synthesize skip info for this cancellation error.
      let backtrace = Backtrace(forFirstThrowOf: error)
      let sourceContext = SourceContext(backtrace: backtrace, sourceLocation: nil)
      self.init(comment: nil, sourceContext: sourceContext)
    } else {
      return nil
    }
  }
}

// MARK: - Conversion to/from ABI types

extension SkipInfo {
  /// Initialize an instance of this type from the given value.
  ///
  /// SkipInfo is only non-nil for the skip/cancel event kinds.
  ///
  /// - Parameters:
  ///   - event: The encoded event to initialize this instance from.
  ///
  /// Reconstructs ``SkipInfo`` from the comments and
  /// source location stored in the encoded event.
  init?<V>(decoding event: ABI.EncodedEvent<V>) {
    // Only skip/cancel event kinds can decode SkipInfo.
    switch event.kind {
    case .testCancelled, .testCaseCancelled, .testSkipped:
      break
    default:
      return nil
    }

    // Typically only a single comment is expected for SkipInfo.
    let comment = event._comments?.first.map(Comment.init(rawValue:))
    let sourceLocation = event._sourceLocation.flatMap(SourceLocation.init(decoding:))
    let sourceContext = SourceContext(backtrace: nil, sourceLocation: sourceLocation)
    self.init(comment: comment, sourceContext: sourceContext)
  }
}

// MARK: - Deprecated

extension SkipInfo {
  @available(*, deprecated, message: "Use init(comment:sourceContext:) and pass an explicit SourceContext.")
  public init(comment: Comment? = nil) {
    self.init(comment: comment, sourceContext: .init(backtrace: .current(), sourceLocation: nil))
  }
}
