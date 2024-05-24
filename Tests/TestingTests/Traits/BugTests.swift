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
  @Test(".bug() with URL string")
  func bugFactoryMethodWithURLString() throws {
    let trait = Bug.bug("https://www.example.com/12345", "Lorem ipsum")
    #expect((trait as Any) is Bug)
    #expect(trait.url == "https://www.example.com/12345")
    #expect(trait.title == "Lorem ipsum")
    #expect(trait.comments == ["Lorem ipsum"])
  }

  @Test(".bug() with String")
  func bugFactoryMethodWithString() throws {
    let trait = Bug.bug(id: "12345", "Lorem ipsum")
    #expect((trait as Any) is Bug)
    #expect(trait.id == "12345")
    #expect(trait.title == "Lorem ipsum")
    #expect(trait.comments == ["Lorem ipsum"])
  }

  @Test(".bug() with SignedInteger")
  func bugFactoryMethodWithSignedInteger() throws {
    let trait = Bug.bug(id: 12345)
    #expect((trait as Any) is Bug)
    #expect(trait.id == "12345")
    #expect(trait.title == nil)
    #expect(trait.comments.isEmpty)
  }

  @Test(".bug() with UnsignedInteger")
  func bugFactoryMethodWithUnsignedInteger() throws {
    let trait = Bug.bug(id: UInt32(12345), "Lorem ipsum")
    #expect((trait as Any) is Bug)
    #expect(trait.id == "12345")
    #expect(trait.title == "Lorem ipsum")
    #expect(trait.comments == ["Lorem ipsum"])
  }

  @Test("Comparing Bug instances",
    arguments: [
      Bug.bug(id: 12345),
      .bug("https://www.example.com/67890"),
    ], [
      Bug.bug("67890"),
      .bug("https://www.example.com/12345"),
    ]
  )
  func bugComparison(lhs: Bug, rhs: Bug) throws {
    #expect(lhs != rhs)
  }

  @Test(".bug() is not recursively applied")
  func bugIsNotRecursive() async throws {
    let trait = Bug.bug(id: 12345)
    #expect(!trait.isRecursive)
  }

  @Test("Test.associatedBugs property")
  func testAssociatedBugsProperty() {
    let test = Test(.bug(id: 12345), .disabled(), .bug(id: 67890), .bug(id: 24680), .bug(id: 54321)) {}
    let bugIdentifiers = test.associatedBugs
    #expect(bugIdentifiers.count == 4)
    #expect(bugIdentifiers[0].id == "12345")
    #expect(bugIdentifiers[1].id == "67890")
    #expect(bugIdentifiers[2].id == "24680")
    #expect(bugIdentifiers[3].id == "54321")
  }

  @Test("Bug hashing")
  func hashing() {
    let traits: Set<Bug> = [.bug(id: 12345), .bug(id: "12345"), .bug(id: 12345), .bug(id: "67890"), .bug("https://www.example.com/12345")]
    #expect(traits.count == 3)
  }

#if canImport(Foundation)
  @Test("Encoding/decoding")
  func encodingAndDecoding() throws {
    let original = Bug.bug(id: 12345, "Lorem ipsum")
    let copy = try JSON.encodeAndDecode(original)
    #expect(original == copy)
  }
#endif
}
