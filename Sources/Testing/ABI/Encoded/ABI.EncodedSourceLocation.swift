//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
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
  struct EncodedSourceLocation<V>: Sendable where V: ABI.Version {
    var sourceLocation: SourceLocation

    init(encoding sourceLocation: borrowing SourceLocation) {
      self.sourceLocation = copy sourceLocation
    }
  }
}

// MARK: - Decodable

extension ABI.EncodedSourceLocation: Decodable {
  init(from decoder: any Decoder) throws {
    self.sourceLocation = try SourceLocation(from: decoder)
  }
}

// MARK: - JSON.Serializable

extension ABI.EncodedSourceLocation: JSON.Serializable {
  func makeJSON() throws -> some Collection<UInt8> {
    var dict = JSON.HeterogenousDictionary()

    try dict.updateValue(sourceLocation._filePath, forKey: "_filePath")
    try dict.updateValue(sourceLocation.fileID, forKey: "fileID")
    try dict.updateValue(sourceLocation.line, forKey: "line")
    try dict.updateValue(sourceLocation.column, forKey: "column")

    return try dict.makeJSON()
  }
}
