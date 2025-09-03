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
  /// Whether or not we can create an instance of ``SkipInfo`` from an instance
  /// of XCTest's `XCTSkip` type.
  static var isXCTSkipInteropEnabled: Bool {
    _XCTSkipCopyInfoDictionary != nil
  }

  /// Gather the properties of an instance of `XCTSkip` that we can use to
  /// construct an instance of ``SkipInfo``.
  private static let _XCTSkipCopyInfoDictionary: (@convention(c) (Unmanaged<AnyObject>) -> Unmanaged<AnyObject>?)? = {
#if !SWT_NO_DYNAMIC_LINKING
    // Check if XCTest exports a function for us to invoke to get the bits of
    // the XCTSkip error we need. If so, call it and extract them.
    var result = symbol(named: "_XCTSkipCopyInfoDictionary").map {
      castCFunction(at: $0, to: (@convention(c) (Unmanaged<AnyObject>) -> Unmanaged<AnyObject>?).self)
    }
    if let result {
      return result
    }

#if _runtime(_ObjC) && canImport(Foundation)
    if result == nil {
      // Temporary workaround that allows us to implement XCTSkip bridging on
      // Apple platforms where XCTest does not export the necessary function.
      return { errorAddress in
        guard let error = errorAddress.takeUnretainedValue() as? any Error,
              error._domain == "com.apple.XCTestErrorDomain" && error._code == 106,
              let userInfo = error._userInfo as? [String: Any],
              let skippedContext = userInfo["XCTestErrorUserInfoKeySkippedTestContext"] as? NSObject else {
          return nil
        }

        var result = [String: Any]()
        result["XCTSkipMessage"] = skippedContext.value(forKey: "message")
        result["XCTSkipCallStack"] = skippedContext.value(forKeyPath: "sourceCodeContext.callStack.address")
        return .passRetained(result as AnyObject)
      }
    }
#endif

    return result
#else
    return nil
#endif
  }()

  /// Attempt to create an instance of this type from an instance of XCTest's
  /// `XCTSkip` error type or its Objective-C equivalent.
  ///
  /// - Parameters:
  ///   - error: The error that may be an instance of `XCTSkip`.
  ///
  /// - Returns: An instance of ``SkipInfo`` corresponding to `error`, or `nil`
  ///   if `error` was not an instance of `XCTSkip`.
  private static func _fromXCTSkip(_ error: any Error) -> Self? {
    let errorObject = error as AnyObject
    if let info = _XCTSkipCopyInfoDictionary?(.passUnretained(errorObject))?.takeRetainedValue() as? [String: Any] {
      let comment = (info["XCTSkipMessage"] as? String).map { Comment(rawValue: $0) }
      let backtrace = (info["XCTSkipCallStack"] as? [UInt64]).map { Backtrace(addresses: $0) }
      let sourceContext = SourceContext(
        backtrace: backtrace ?? Backtrace(forFirstThrowOf: error),
        sourceLocation: nil
      )
      return SkipInfo(comment: comment, sourceContext: sourceContext)
    }

    return nil
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
