//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ExperimentalSnapshotting) @_spi(ExperimentalParameterizedTesting) import Testing

#if canImport(Foundation)
import Foundation
#endif

@Suite("Test.Snapshot tests")
struct Test_SnapshotTests {
#if canImport(Foundation)
  @Test("Codable")
  func codable() async throws {
    let test = try #require(Test.current)
    let snapshot = await Test.Snapshot(snapshotting: test)
    let decoded = try JSONDecoder().decode(Test.Snapshot.self, from: JSONEncoder().encode(snapshot))

    #expect(decoded.id == snapshot.id)
    #expect(decoded.name == snapshot.name)
    #expect(decoded.displayName == snapshot.displayName)
    #expect(decoded.sourceLocation == snapshot.sourceLocation)
    // FIXME: Compare traits as well, once they are included.
    #expect(decoded.parameters == snapshot.parameters)
  }
#endif
}
