//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing

@Suite("Bug Tests", .tags(.traitRelated))
struct BugTests {
  @Test(".bug() with String")
  func bugFactoryMethodWithString() throws {
    let trait = Bug.bug("12345", "Lorem ipsum")
    #expect((trait as Any) is Bug)
    #expect(trait.identifier == "12345")
    #expect(trait.comment == "Lorem ipsum")
    #expect(trait.comments == ["Lorem ipsum"])
  }

  @Test(".bug() with SignedInteger")
  func bugFactoryMethodWithSignedInteger() throws {
    let trait = Bug.bug(12345)
    #expect((trait as Any) is Bug)
    #expect(trait.identifier == "12345")
    #expect(trait.comment == nil)
    #expect(trait.comments.isEmpty)
  }

  @Test(".bug() with UnsignedInteger")
  func bugFactoryMethodWithUnsignedInteger() throws {
    let trait = Bug.bug(UInt32(12345), "Lorem ipsum")
    #expect((trait as Any) is Bug)
    #expect(trait.identifier == "12345")
    #expect(trait.comment == "Lorem ipsum")
    #expect(trait.comments == ["Lorem ipsum"])
  }

  @Test("Comparing Bug instances")
  func bugComparison() throws {
    let lhs = Bug.bug(12345)
    let rhs = Bug.bug("67890")

    #expect(lhs != rhs)
    #expect(lhs < rhs)
    #expect(rhs > lhs)
  }

  @Test(".bug() is not recursively applied")
  func bugIsNotRecursive() async throws {
    let trait = Bug.bug(12345)
    #expect(!trait.isRecursive)
  }

  @Test("Test.associatedBugs property")
  func testAssociatedBugsProperty() {
    let test = Test(.bug(12345), .disabled(), .bug(67890), .bug(24680), .bug(54321)) {}
    let bugIdentifiers = test.associatedBugs
    #expect(bugIdentifiers.count == 4)
    #expect(bugIdentifiers[0].identifier == "12345")
    #expect(bugIdentifiers[1].identifier == "67890")
    #expect(bugIdentifiers[2].identifier == "24680")
    #expect(bugIdentifiers[3].identifier == "54321")
  }

  @Test("Bug hashing")
  func hashing() {
    let traits: Set<Bug> = [.bug(12345), .bug(12345), .bug(12345), .bug("67890")]
    #expect(traits.count == 2)
  }

#if canImport(Foundation)
  @Test("Encoding/decoding")
  func encodingAndDecoding() throws {
    let original = Bug.bug(12345, "Lorem ipsum")
    let copy = try JSON.encodeAndDecode(original)
    #expect(original == copy)
  }
#endif
}
