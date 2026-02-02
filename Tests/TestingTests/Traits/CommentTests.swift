//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

@Suite("Comment Tests", .tags(.traitRelated))
struct CommentTests {
  @Test(".comment() factory method")
  func commentFactoryMethod() {
    let trait = Comment.comment("No comment")
    #expect((trait as Any) is Comment)
  }

  @Test("Test.comments property")
  func testCommentsGetter() async throws {
    let plan = await Runner.Plan(selecting: CommentedTests.self)

    let commentTestsType = try #require(plan.steps.map(\.test).first { $0.name == "CommentedTests" })
    #expect(commentTestsType.comments == ["A"])

    // Comments are not inherited
    let example1 = try #require(plan.steps.map(\.test).first { $0.name == "example1()" })
    #expect(example1.comments == ["B", "C"])

    let example2 = try #require(plan.steps.map(\.test).first { $0.name == "example2()" })
    #expect(example2.comments == [
      "// D",
      "/// E",
      "/* F */",
      "/** G */",
    ])

    let example3 = try #require(plan.steps.map(\.test).first { $0.name == "example3()" })
    #expect(example3.comments == ["H", "I"])
    #expect(example3.comments(from: Comment.self) == ["H"])

    let innerType = try #require(plan.steps.map(\.test).first { $0.name == "Inner" })
    #expect(innerType.comments == ["// J"])

#if !SWT_NO_GLOBAL_ACTORS
    let example4 = try #require(plan.steps.map(\.test).first { $0.name == "example4()" })
    #expect(example4.comments == ["// K"])

    let inner2Type = try #require(plan.steps.map(\.test).first { $0.name == "Inner2" })
    #expect(inner2Type.comments == ["// L"])
#endif
  }

  @Test("Explicitly nil comment")
  func explicitlyNilComment() {
    #expect(true as Bool, nil as Comment?)
  }

  @Test("String interpolation")
  func stringInterpolation() {
    let value1: Int = 123
    let value2: Int? = nil
    let value3: Any.Type = Int.self
    let value4: String? = nil
    let comment: Comment = "abc\(value1)def\(value2)ghi\(value3)\(value4)"
    #expect(comment.rawValue == "abc123defnilghiIntnil")
  }

  @Test("String interpolation with a custom type")
  func stringInterpolationWithCustomType() {
    struct S: CustomStringConvertible, CustomTestStringConvertible {
      var description: String {
        "wrong!"
      }

      var testDescription: String {
        "right!"
      }
    }

    let comment: Comment = "abc\(S())def\(S() as S?)ghi\(S.self)jkl\("string")"
    #expect(comment.rawValue == "abcright!defright!ghiSjklstring")
  }

  @Test("String interpolation with a move-only value")
  func stringInterpolationWithMoveOnlyValue() {
    struct S: ~Copyable {}

    let s = S()
    let comment: Comment = "abc\(s)"
    #expect(comment.rawValue == "abcinstance of 'S'")
    _ = s
  }

  @Test("String interpolation with a move-only value conforming to CustomTestStringConvertible")
  func stringInterpolationWithMoveOnlyValueConformingToProtocol() {
    struct S: CustomTestStringConvertible, ~Copyable {
      var testDescription: String {
        "right!"
      }
    }

    let s = S()
    let comment: Comment = "abc\(s)"
    #expect(comment.rawValue == "abcright!")
    _ = s
  }
}

// MARK: - Fixtures

@Suite(.hidden, .comment("A"))
struct CommentedTests {
  @Test(.hidden, .comment("B"), .comment("C"))
  func example1() {}

  // D
  /// E
  /* F */
  /** G */
  @Test(.hidden)
  func example2() {}

  @Test(.hidden, .comment("H"), .disabled("I"))
  func example3() {}

  // J
  @Suite struct Inner {}

#if !SWT_NO_GLOBAL_ACTORS
  // K
  @MainActor
  @Test(.hidden)
  func example4() {}

  // L
  @MainActor
  @Suite(.hidden) struct Inner2 {}
#endif
}
