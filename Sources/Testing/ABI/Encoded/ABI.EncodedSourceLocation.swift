//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation)
private import Foundation
#endif

extension ABI {
  /// A type implementing the JSON encoding of ``SourceLocation`` for the ABI
  /// entry point and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedSourceLocation<V>: Sendable where V: ABI.Version {
    /// See ``SourceLocation`` for a discussion of these properties.
    var fileID: String?
    var filePath: String?
    var _filePath: String?
    var line: Int
    var column: Int

    init(encoding sourceLocation: borrowing SourceLocation) {
      fileID = sourceLocation.fileID

      // When using the 6.3 schema, don't encode synthesized file IDs.
      if V.versionNumber >= ABI.v6_3.versionNumber,
         sourceLocation.moduleName == SourceLocation.synthesizedModuleName {
        fileID = nil
      }

      // When using the 6.3 schema, we encode both "filePath" and "_filePath" to
      // ease migration for existing tools.
      if V.versionNumber >= ABI.v6_3.versionNumber {
        filePath = sourceLocation.filePath
      }
      if V.versionNumber <= ABI.v6_3.versionNumber {
        _filePath = sourceLocation.filePath
      }

      line = sourceLocation.line
      column = sourceLocation.column
    }
  }
}

// MARK: - Codable

extension ABI.EncodedSourceLocation: Codable {}

// MARK: -

extension SourceLocation {
  init?<V>(_ sourceLocation: ABI.EncodedSourceLocation<V>) {
    let fileID = sourceLocation.fileID
    guard let filePath = sourceLocation.filePath ?? sourceLocation._filePath else {
      return nil
    }
    let line = max(1, sourceLocation.line)
    let column = max(1, sourceLocation.column)

    self.init(fileIDSynthesizingIfNeeded: fileID, filePath: filePath, line: line, column: column)
  }
}
