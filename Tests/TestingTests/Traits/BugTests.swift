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

@Suite("Bug Tests", .tags("trait"))
struct BugTests {
  @Test(".bug() with String")
  func bugFactoryMethodWithString() throws {
    let trait = Bug.bug("12345")
    #expect((trait as Any) is Bug)
    #expect(trait.identifier == "12345")
  }

  @Test(".bug() with SignedInteger")
  func bugFactoryMethodWithSignedInteger() throws {
    let trait = Bug.bug(12345)
    #expect((trait as Any) is Bug)
    #expect(trait.identifier == "12345")
  }

  @Test(".bug() with UnsignedInteger")
  func bugFactoryMethodWithUnsignedInteger() throws {
    let trait = Bug.bug(UInt32(12345))
    #expect((trait as Any) is Bug)
    #expect(trait.identifier == "12345")
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
    let test = Test(.bug(12345), .disabled(), .bug(67890), .bug(24680, relationship: .uncoveredBug), .bug(54321, relationship: .verifiesFix)) {}
    let bugIdentifiers = test.associatedBugs
    #expect(bugIdentifiers.count == 4)
    #expect(bugIdentifiers[0].identifier == "12345")
    #expect(bugIdentifiers[1].identifier == "67890")
    #expect(bugIdentifiers[2].identifier == "24680")
    #expect(bugIdentifiers[3].identifier == "54321")
  }

  @Test(".bug() with String and relationship")
  func bugWithStringAndRelationship() {
    let trait = Bug.bug("12345", relationship: .uncoveredBug)
    #expect((trait as Any) is Bug)
    #expect(trait.identifier == "12345")
    #expect(trait.relationship == .uncoveredBug)
  }

  @Test(".bug() with number and relationship")
  func bugWithNumericAndRelationship() {
    let trait = Bug.bug(67890, relationship: .uncoveredBug)
    #expect((trait as Any) is Bug)
    #expect(trait.identifier == "67890")
    #expect(trait.relationship == .uncoveredBug)
  }

  @Test("Bug hashing")
  func hashing() {
    let traits: Set<Bug> = [.bug(12345), .bug(12345), .bug(12345, relationship: .uncoveredBug), .bug("67890")]
    #expect(traits.count == 2)
  }

  @Test(.bug(12345, relationship: .verifiesFix)) func f() {
    #expect(1 == 2)
  }

  @Test(.bug(123456789, relationship: .reproducesBug)) func g() {
    #expect(1 == 2)
  }
}
