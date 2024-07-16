//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_SNAPSHOT_TYPES
/// A serializable snapshot of an `Error` value.
///
/// This type conforms to `Error` as well, meaning it can be thrown and treated
/// as an error, however it is not considered equal to the underlying error it
/// is a snapshot of.
@_spi(ForToolsIntegrationOnly)
public struct ErrorSnapshot: Error {
  /// A description of this instance's underlying error, formatted using
  /// ``Swift/String/init(describingForTest:)``.
  public var description: String

  /// Information about the type of this instance's underlying error.
  public var typeInfo: TypeInfo

  /// Initialize an instance of this type by taking a snapshot of the specified
  /// error.
  ///
  /// - Parameters:
  ///   - error: The underlying error to snapshot.
  public init(snapshotting error: any Error) {
    description = String(describingForTest: error)
    typeInfo = TypeInfo(describingTypeOf: error)
  }
}

// MARK: - CustomStringConvertible

extension ErrorSnapshot: CustomStringConvertible {}

// MARK: - Codable

extension ErrorSnapshot: Codable {}
#endif
