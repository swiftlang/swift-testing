//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABI {
  /// A type implementing the JSON encoding of ``SourceLocation`` for the ABI
  /// entry point and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  public struct EncodedSourceLocation<V>: Sendable where V: ABI.Version {
    /// The file ID of the source file.
    public var fileID: String?

    /// The file path of the source file.
    public var filePath: String? {
      get {
        _filePath_v6_3 ?? _filePath_v0
      }
      set {
        // When using the 6.3 schema, we encode both "filePath" and "_filePath"
        // to ease migration for existing tools.
        if V.versionNumber >= ABI.v6_3.versionNumber {
          _filePath_v6_3 = newValue
        }
        if V.versionNumber <= ABI.v6_3.versionNumber {
          _filePath_v0 = newValue
        }
      }
    }

    /// The line in the source file.
    public var line: Int = 1

    /// The column in the source file.
    public var column: Int = 1

    /// Storage for ``filePath`` under the `"_filePath"` JSON key, as used prior
    /// to Swift 6.3.
    private var _filePath_v0: String?

    /// Storage for ``filePath`` under the `"filePath"` JSON key, as used in
    /// Swift 6.3 and newer.
    private var _filePath_v6_3: String?

    public init(encoding sourceLocation: borrowing SourceLocation) {
      fileID = sourceLocation.fileID
      filePath = sourceLocation.filePath
      line = sourceLocation.line
      column = sourceLocation.column

      // When using the 6.3 schema, don't encode synthesized file IDs.
      if V.versionNumber >= ABI.v6_3.versionNumber,
         sourceLocation.moduleName == SourceLocation.synthesizedModuleName {
        fileID = nil
      }
    }
  }
}

// MARK: - Codable

extension ABI.EncodedSourceLocation: Codable {
  private enum CodingKeys: String, CodingKey {
    case fileID
    case _filePath_v0 = "_filePath"
    case _filePath_v6_3 = "filePath"
    case line
    case column
  }
}

// MARK: -

@_spi(ForToolsIntegrationOnly)
extension SourceLocation {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - sourceLocation: The encoded source location to initialize this
  ///     instance from.
  ///
  /// If `sourceLocation` does not specify a value for its `fileID` field, the
  /// testing library synthesizes a value from its `filePath` property and
  /// hard-codes a module name of `"__C"`.
  public init?<V>(_ sourceLocation: ABI.EncodedSourceLocation<V>) {
    let fileID = sourceLocation.fileID
    let filePath = sourceLocation.filePath
    let line = max(1, sourceLocation.line)
    let column = max(1, sourceLocation.column)

    if let fileID, !fileID.utf8.contains(UInt8(ascii: "/")) {
      return nil
    }
    guard let filePath else {
      return nil
    }

    self.init(fileIDSynthesizingIfNeeded: fileID, filePath: filePath, line: line, column: column)
  }
}
