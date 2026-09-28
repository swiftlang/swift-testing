//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
private import _TestingInternals

@Suite("Tag/Tag List Tests", .tags(.traitRelated))
struct TagListTests {
  @Test(".tags() factory method with one tag")
  func tagListFactoryMethodWithOneString() throws {
    let trait = Tag.List.tags(.namedConstant)
    #expect((trait as Any) is Tag.List)
    #expect(trait.tags == [.namedConstant])
  }

  @Test(".tags() factory method with two tags")
  func tagListFactoryMethodWithTwoStrings() throws {
    let trait = Tag.List.tags(.namedConstant, .anotherConstant)
    #expect((trait as Any) is Tag.List)
    #expect(trait.tags == [.namedConstant, .anotherConstant])
  }

  @Test(".tags() factory method with colors", .tags(.red, .orange, .yellow, .green, .blue, .purple))
  func tagListFactoryMethodWithColors() throws {
    let trait = Tag.List.tags(.red, .orange, .yellow, .green, .blue, .purple)
    #expect((trait as Any) is Tag.List)
    #expect(trait.tags == [.red, .orange, .yellow, .green, .blue, .purple])
    #expect(trait.tags == [
      Tag(kind: .staticMember("red")),
      Tag(kind: .staticMember("orange")),
      Tag(kind: .staticMember("yellow")),
      Tag(kind: .staticMember("green")),
      Tag(kind: .staticMember("blue")),
      Tag(kind: .staticMember("purple"))
    ])
    #expect(trait.tags.allSatisfy { $0.isPredefinedColor })
  }

  @Test("Tag.description property", arguments: [
    Tag.namedConstant: ".namedConstant",
    .anotherConstant: ".anotherConstant",
    .red: ".red",
    .orange: ".orange",
    .yellow: ".yellow",
    .green: ".green",
    .blue: ".blue",
    .purple: ".purple",
  ])
  func tagDescription(tag: Tag, expectedDescription: String) throws {
    #expect(String(describing: tag) == expectedDescription)
  }

  @Test("Tag.List.description property")
  func tagListDescription() throws {
    let trait = Tag.List.tags(.namedConstant, .anotherConstant, .red, .orange, .yellow, .green, .blue, .purple)
    #expect((trait as Any) is Tag.List)
    #expect(String(describing: trait) == ".namedConstant, .anotherConstant, .red, .orange, .yellow, .green, .blue, .purple")
  }

  @Test("Tag.List comparisons")
  func tagListComparison() throws {
    #expect(Tag("A") != Tag("B"))
    #expect(Tag("A") < Tag("B"))
    #expect(Tag("B") > Tag("A"))
    #expect(!(Tag("B") < Tag("A")))
  }

  @Test("Test.tags property")
  func testTagsProperty() {
    let test = Test(.tags(Tag("A"), Tag("B"))) {}
    #expect(test.tags == [Tag("A"), Tag("B")])
  }

  @Test("Tags are recursively applied")
  func tagsAreRecursivelyApplied() async throws {
    let plan = await Runner.Plan(selecting: TagTests.self)

    let typeTest = try #require(plan.steps.map(\.test).first { $0.name == "TagTests" })
    #expect(typeTest.tags == [.fromType])
    let functionTest = try #require(plan.steps.map(\.test).first { $0.name == "test()" })
    #expect(functionTest.tags == [.fromFunction, .fromType])

    let functionTest2 = try #require(plan.steps.map(\.test).first { $0.name == "variations()" })
    #expect(functionTest2.tags.contains(.NestedType.deeperTag))
    #expect(!functionTest2.tags.contains(.OtherNestedType.deeperTag))
  }

  @Test("Tags can be parsed from user-provided strings")
  func userProvidedStringValues() {
    #expect(Tag(userProvidedStringValue: "abc123") == Tag(kind: .staticMember("abc123")))
    #expect(Tag(userProvidedStringValue: ".red") == .red)
  }

#if !SWT_NO_CODABLE
  @Test("Encoding/decoding tags")
  func encodeAndDecodeTags() throws {
    let array: [Tag] = [.red, .orange, Tag("abc123"), Tag(".abc123")]
    let array2 = try JSON.encodeAndDecode(array)
    #expect(array == array2)
  }

  @Test("Tags as codable dictionary keys")
  func encodeAndDecodeTagsAsDictionaryKeys() throws {
    let dict: [Tag: Int] = [
      .red: 0,
      .orange: 1,
      Tag("abc123"): 2,
      Tag(".def456"): 3,
    ]
    let dict2 = try JSON.encodeAndDecode(dict)
    #expect(dict == dict2)
  }
#endif
}

// MARK: - Fixtures

extension Tag {
  @Tag static var namedConstant: Tag
  @Tag static var anotherConstant: Tag

  enum NestedType {
    @Tag static var deeperTag: Tag
  }

  enum OtherNestedType {
    @Tag static var deeperTag: Tag
  }

  @Tag static var fromType: Tag
  @Tag static var fromFunction: Tag
  @Tag static var fromFunctionPartiallyQualified: Tag
  @Tag static var fromFunctionFullyQualified: Tag
}

@Suite(.hidden, .tags(.fromType))
struct TagTests {
  @Test(.hidden, .tags(.fromFunction))
  func test() async throws {}

  @Test(
    .hidden,
    Tag.List.tags(.fromFunctionPartiallyQualified),
    Testing.Tag.List.tags(.fromFunctionFullyQualified),
    Testing::Tag.List.tags(.fromFunctionFullyQualified),
    Testing::Testing.Tag.List.tags(.fromFunctionFullyQualified),
    .tags(.namedConstant, .NestedType.deeperTag, Testing.Tag.anotherConstant),
    .tags(.namedConstant, .NestedType.deeperTag, Testing::Tag.anotherConstant),
    .tags(.namedConstant, .NestedType.deeperTag, Testing::Testing.Tag.anotherConstant)
  )
  func variations() async throws {}
}
