//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if _runtime(_ObjC) && canImport(Foundation)
private import ObjectiveC
private import Foundation
#endif

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
  /// The Swift type corresponding to `XCTSkip` if XCTest has been linked into
  /// the current process.
  private static let _xctSkipType: Any.Type? = _typeByName("6XCTest7XCTSkipV") // _mangledTypeName(XCTest.XCTSkip.self)

  /// Whether or not we can create an instance of ``SkipInfo`` from an instance
  /// of XCTest's `XCTSkip` type.
  static var isXCTSkipInteropEnabled: Bool {
    _xctSkipType != nil
  }

  /// Attempt to create an instance of this type from an instance of XCTest's
  /// `XCTSkip` error type.
  ///
  /// - Parameters:
  ///   - error: The error that may be an instance of `XCTSkip`.
  ///
  /// - Returns: An instance of ``SkipInfo`` corresponding to `error`, or `nil`
  ///   if `error` was not an instance of `XCTSkip`.
  private static func _fromXCTSkip(_ error: any Error) -> Self? {
    guard let _xctSkipType, type(of: error) == _xctSkipType else {
      return nil
    }

    let userInfo = error._userInfo as? [String: Any] ?? [:]

    if let skipInfoJSON = userInfo["XCTestErrorUserInfoKeyBridgedJSONRepresentation"] as? any RandomAccessCollection {
      func open(_ skipInfoJSON: some RandomAccessCollection) -> Self? {
        try? skipInfoJSON.withContiguousStorageIfAvailable { skipInfoJSON in
          try JSON.decode(Self.self, from: UnsafeRawBufferPointer(skipInfoJSON))
        }
      }
      if let skipInfo = open(skipInfoJSON) {
        return skipInfo
      }
    }

    var comment: Comment?
    var backtrace: Backtrace?
#if _runtime(_ObjC) && canImport(Foundation)
    // Temporary workaround that allows us to implement XCTSkip bridging on
    // Apple platforms where XCTest does not provide the user info values above.
    if let skippedContext = userInfo["XCTestErrorUserInfoKeySkippedTestContext"] as? NSObject {
      if let message = skippedContext.value(forKey: "message") as? String {
        comment = Comment.init(rawValue: message)
      }
      if let callStackAddresses = skippedContext.value(forKeyPath: "sourceCodeContext.callStack.address") as? [UInt64] {
        backtrace = Backtrace(addresses: callStackAddresses)
      }
    }
#else
    // On non-Apple platforms, we just don't have this information.
    // SEE: swift-corelibs-xctest-#511
#endif
    if backtrace == nil {
      backtrace = Backtrace(forFirstThrowOf: error)
    }

    let sourceContext = SourceContext(backtrace: backtrace, sourceLocation: nil)
    return SkipInfo(comment: comment, sourceContext: sourceContext)
  }

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
    } else if let skipInfo = Self._fromXCTSkip(error) {
      // XCTSkip doesn't cancel the current test or task for us, so we do it
      // here as part of the bridging process.
      self = skipInfo
      if Test.Case.current != nil {
        Test.Case.cancel(with: skipInfo)
      } else if Test.current != nil {
        Test.cancel(with: skipInfo)
      }
    } else {
      return nil
    }
  }
}

// MARK: - Deprecated

extension SkipInfo {
  @available(*, deprecated, message: "Use init(comment:sourceContext:) and pass an explicit SourceContext.")
  public init(comment: Comment? = nil) {
    self.init(comment: comment, sourceContext: .init(backtrace: .current(), sourceLocation: nil))
  }
}
