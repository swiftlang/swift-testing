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

    var message = userInfo["XCTestErrorUserInfoKeyMessage"] as? String
    var explanation = userInfo["XCTestErrorUserInfoKeyExplanation"] as? String
    var callStackAddresses = userInfo["XCTestErrorUserInfoKeyCallStackAddresses"] as? [UInt64]
    let sourceLocation: SourceLocation? = (userInfo["XCTestErrorUserInfoKeySourceLocation"] as? [String: Any]).flatMap { sourceLocation in
      guard let fileID = sourceLocation["fileID"] as? String,
            let filePath = sourceLocation["filePath"] as? String,
            let line = sourceLocation["line"] as? Int,
            let column = sourceLocation["column"] as? Int else {
        return nil
      }
      return SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
    }

#if _runtime(_ObjC) && canImport(Foundation)
    // Temporary workaround that allows us to implement XCTSkip bridging on
    // Apple platforms where XCTest does not provide the user info values above.
    if message == nil && explanation == nil && callStackAddresses == nil,
       let skippedContext = userInfo["XCTestErrorUserInfoKeySkippedTestContext"] as? NSObject {
      message = skippedContext.value(forKey: "message") as? String
      explanation = skippedContext.value(forKey: "explanation") as? String
      callStackAddresses = skippedContext.value(forKeyPath: "sourceCodeContext.callStack.address") as? [UInt64]
    }
#endif

    let comment: Comment? = switch (message, explanation) {
    case let (.some(message), .some(explanation)):
      "\(message) - \(explanation)"
    case let (_, .some(comment)), let (.some(comment), _):
      Comment(rawValue: comment)
    default:
      nil
    }
    let backtrace: Backtrace? = callStackAddresses.map { callStackAddresses in
      Backtrace(addresses: callStackAddresses)
    }

    let sourceContext = SourceContext(
      backtrace: backtrace ?? Backtrace(forFirstThrowOf: error),
      sourceLocation: sourceLocation
    )
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
