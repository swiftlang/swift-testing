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
#if canImport(Foundation)
import Foundation
@_spi(Experimental) import _Testing_Foundation
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
@_spi(Experimental) import _Testing_UniformTypeIdentifiers
#endif
private import _TestingInternals

@Suite("Attachment Tests")
struct AttachmentTests {
  @Test func saveValue() {
    let attachableValue = MyAttachable(string: "<!doctype html>")
    let attachment = Test.Attachment(attachableValue, named: "AttachmentTests.saveValue.html")
    attachment.attach()
  }

#if !SWT_NO_FILE_IO
  func compare(_ attachableValue: borrowing MySendableAttachable, toContentsOfFileAtPath filePath: String) throws {
    let file = try FileHandle(forReadingAtPath: filePath)
    let bytes = try file.readToEnd()

    let decodedValue = if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
      try #require(String(validating: bytes, as: UTF8.self))
    } else {
      String(decoding: bytes, as: UTF8.self)
    }
    #expect(decodedValue == attachableValue.string)
  }

  @Test func writeAttachment() throws {
    let attachableValue = MySendableAttachable(string: "<!doctype html>")
    let attachment = Test.Attachment(attachableValue, named: "loremipsum.html")

    // Write the attachment to disk, then read it back.
    let filePath = try attachment.write(toFileInDirectoryAtPath: temporaryDirectoryPath())
    defer {
      remove(filePath)
    }
    try compare(attachableValue, toContentsOfFileAtPath: filePath)
  }

  @Test func writeAttachmentWithNameConflict() throws {
    // A sequence of suffixes that are guaranteed to cause conflict.
    let randomBaseValue = UInt64.random(in: 0 ..< (.max - 10))
    var suffixes = (randomBaseValue ..< randomBaseValue + 10).lazy
      .flatMap { [$0, $0, $0] }
      .map { String($0, radix: 36) }
      .makeIterator()
    let baseFileName = "\(UInt64.random(in: 0 ..< .max))loremipsum.html"
    var createdFilePaths = [String]()
    defer {
      for filePath in createdFilePaths {
        remove(filePath)
      }
    }

    for i in 0 ..< 5 {
      let attachableValue = MySendableAttachable(string: "<!doctype html>\(i)")
      let attachment = Test.Attachment(attachableValue, named: baseFileName)

      // Write the attachment to disk, then read it back.
      let filePath = try attachment.write(toFileInDirectoryAtPath: temporaryDirectoryPath(), appending: suffixes.next()!)
      createdFilePaths.append(filePath)
      let fileName = try #require(filePath.split { $0 == "/" || $0 == #"\"# }.last)
      if i == 0 {
        #expect(fileName == baseFileName)
      } else {
        #expect(fileName != baseFileName)
      }
      try compare(attachableValue, toContentsOfFileAtPath: filePath)
    }
  }

  @Test func writeAttachmentWithMultiplePathExtensions() throws {
    let attachableValue = MySendableAttachable(string: "<!doctype html>")
    let attachment = Test.Attachment(attachableValue, named: "loremipsum.tar.gz.gif.jpeg.html")

    // Write the attachment to disk once to ensure the original filename is not
    // available and we add a suffix.
    let originalFilePath = try attachment.write(toFileInDirectoryAtPath: temporaryDirectoryPath())
    defer {
      remove(originalFilePath)
    }

    // Write the attachment to disk, then read it back.
    let suffix = String(UInt64.random(in: 0 ..< .max), radix: 36)
    let filePath = try attachment.write(toFileInDirectoryAtPath: temporaryDirectoryPath(), appending: suffix)
    defer {
      remove(filePath)
    }
    let fileName = try #require(filePath.split { $0 == "/" || $0 == #"\"# }.last)
    #expect(fileName == "loremipsum-\(suffix).tar.gz.gif.jpeg.html")
    try compare(attachableValue, toContentsOfFileAtPath: filePath)
  }

#if os(Windows)
  static let maximumNameCount = Int(_MAX_FNAME)
  static let reservedNames = ["CON", "COM0", "LPT2"]
#else
  static let maximumNameCount = Int(NAME_MAX)
  static let reservedNames: [String] = []
#endif

  @Test(arguments: [
    #"/\:"#,
    String(repeating: "a", count: maximumNameCount),
    String(repeating: "a", count: maximumNameCount + 1),
    String(repeating: "a", count: maximumNameCount + 2),
  ] + reservedNames) func writeAttachmentWithBadName(name: String) throws {
    let attachableValue = MySendableAttachable(string: "<!doctype html>")
    let attachment = Test.Attachment(attachableValue, named: name)

    // Write the attachment to disk, then read it back.
    let filePath = try attachment.write(toFileInDirectoryAtPath: temporaryDirectoryPath())
    defer {
      remove(filePath)
    }
    try compare(attachableValue, toContentsOfFileAtPath: filePath)
  }

  @Test func fileSystemPathIsSetAfterWritingViaEventHandler() async throws {
    var configuration = Configuration()
    configuration.attachmentDirectoryPath = try temporaryDirectoryPath()

    let attachableValue = MySendableAttachable(string: "<!doctype html>")

    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachment = Test.Attachment(attachableValue, named: "loremipsum.html")
        attachment.attach()
      }.run(configuration: configuration) { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }
        valueAttached()

        // BUG: We could use #expect(throws: Never.self) here, but the Swift 6.1
        // compiler crashes trying to expand the macro (rdar://138997009)
        do {
          let filePath = try #require(attachment.fileSystemPath)
          defer {
            remove(filePath)
          }
          try compare(attachableValue, toContentsOfFileAtPath: filePath)
        } catch {
          Issue.record(error)
        }
      }
    }
  }
#endif

  @Test func attachValue() async {
    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachableValue = MyAttachable(string: "<!doctype html>")
        Test.Attachment(attachableValue, named: "loremipsum").attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "loremipsum")
        valueAttached()
      }
    }
  }

  @Test func attachSendableValue() async {
    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachableValue = MySendableAttachable(string: "<!doctype html>")
        Test.Attachment(attachableValue, named: "loremipsum").attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "loremipsum")
        valueAttached()
      }
    }
  }

  @Test func issueRecordedWhenAttachingNonSendableValueThatThrows() async {
    await confirmation("Attachment detected") { valueAttached in
      await confirmation("Issue recorded") { issueRecorded in
        await Test {
          var attachableValue = MyAttachable(string: "<!doctype html>")
          attachableValue.errorToThrow = MyError()
          Test.Attachment(attachableValue, named: "loremipsum").attach()
        }.run { event, _ in
          if case .valueAttached = event.kind {
            valueAttached()
          } else if case let .issueRecorded(issue) = event.kind,
                    case let .errorCaught(error) = issue.kind,
                    error is MyError {
            issueRecorded()
          }
        }
      }
    }
  }

#if canImport(UniformTypeIdentifiers)
  @Test func getAndSetContentType() async {
    let attachableValue = MySendableAttachable(string: "")
    var attachment = Test.Attachment(attachableValue, named: "loremipsum")

    // Get the default (should just be raw bytes at this point.)
    #expect(attachment.contentType == .data)

    // Switch to a UTType and confirm it stuck.
    attachment.contentType = .pdf
    #expect(attachment.contentType == .pdf)
    #expect(attachment.preferredName == "loremipsum.pdf")

    // Convert it to a different UTType.
    attachment.contentType = .jpeg
    #expect(attachment.contentType == .jpeg)
    #expect(attachment.preferredName == "loremipsum.pdf.jpeg")
  }
#endif

#if canImport(Foundation)
#if !SWT_NO_FILE_IO
  @Test func attachContentsOfFileURL() async throws {
    let data = try #require("<!doctype html>".data(using: .utf8))
    let temporaryFileName = "\(UUID().uuidString).html"
    let temporaryPath = try appendPathComponent(temporaryFileName, to: temporaryDirectoryPath())
    let temporaryURL = URL(fileURLWithPath: temporaryPath, isDirectory: false)
    try data.write(to: temporaryURL)
    defer {
      try? FileManager.default.removeItem(at: temporaryURL)
    }

    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachment = try await Test.Attachment(contentsOf: temporaryURL)
        attachment.attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == temporaryFileName)
        #expect(throws: Never.self) {
          try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { buffer in
            #expect(buffer.count == data.count)
          }
        }
        valueAttached()
      }
    }
  }

#if !SWT_NO_PROCESS_SPAWNING
  @Test func attachContentsOfDirectoryURL() async throws {
    let temporaryFileName = UUID().uuidString
    let temporaryPath = try appendPathComponent(temporaryFileName, to: temporaryDirectoryPath())
    let temporaryURL = URL(fileURLWithPath: temporaryPath, isDirectory: false)
    try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)

    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachment = try await Test.Attachment(contentsOf: temporaryURL)
        attachment.attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "\(temporaryFileName).tar.gz")
        valueAttached()
      }
    }
  }
#endif

  @Test func attachUnsupportedContentsOfURL() async throws {
    let url = try #require(URL(string: "https://www.example.com"))
    await #expect(throws: CocoaError.self) {
      _ = try await Test.Attachment(contentsOf: url)
    }
  }
#endif

  @available(_uttypesAPI, *)
  struct CodableAttachmentArguments: Sendable, CustomTestArgumentEncodable, CustomTestStringConvertible {
    var forSecureCoding: Bool
    var contentType: (any Sendable)?
    var pathExtension: String?
    var firstCharacter: Character
    var decode: @Sendable (Data) throws -> String

    @Sendable static func decodeWithJSONDecoder(_ data: Data) throws -> String {
      try JSONDecoder().decode(MyCodableAttachable.self, from: data).string
    }

    @Sendable static func decodeWithPropertyListDecoder(_ data: Data) throws -> String {
      try PropertyListDecoder().decode(MyCodableAttachable.self, from: data).string
    }

    @Sendable static func decodeWithNSKeyedUnarchiver(_ data: Data) throws -> String {
      let result = try NSKeyedUnarchiver.unarchivedObject(ofClass: MySecureCodingAttachable.self, from: data)
      return try #require(result).string
    }

    static func all() -> [Self] {
      var result = [Self]()

      for forSecureCoding in [false, true] {
        let decode = forSecureCoding ? decodeWithNSKeyedUnarchiver : decodeWithPropertyListDecoder
        result += [
          Self(
            forSecureCoding: forSecureCoding,
            firstCharacter: forSecureCoding ? "b" : "{",
            decode: forSecureCoding ? decodeWithNSKeyedUnarchiver : decodeWithJSONDecoder
          )
        ]

        result += [
          Self(forSecureCoding: forSecureCoding, pathExtension: "xml", firstCharacter: "<", decode: decode),
          Self(forSecureCoding: forSecureCoding, pathExtension: "plist", firstCharacter: "b", decode: decode),
        ]

        if !forSecureCoding {
          result += [
            Self(forSecureCoding: forSecureCoding, pathExtension: "json", firstCharacter: "{", decode: decodeWithJSONDecoder),
          ]
        }
      }

      return result
    }

    func encodeTestArgument(to encoder: some Encoder) throws {
      var container = encoder.unkeyedContainer()
      try container.encode(pathExtension)
      try container.encode(forSecureCoding)
      try container.encode(firstCharacter.asciiValue!)
    }

    var testDescription: String {
      "(forSecureCoding: \(forSecureCoding), contentType: \(String(describingForTest: contentType)))"
    }
  }

  @available(_uttypesAPI, *)
  @Test("Attach Codable- and NSSecureCoding-conformant values", .serialized, arguments: CodableAttachmentArguments.all())
  func attachCodable(args: CodableAttachmentArguments) async throws {
    var name = "loremipsum"
    if let ext = args.pathExtension {
      name = "\(name).\(ext)"
    }

    var attachment: Test.Attachment
    if args.forSecureCoding {
      let attachableValue = MySecureCodingAttachable(string: "stringly speaking")
      attachment = Test.Attachment(attachableValue, named: name)
    } else {
      let attachableValue = MyCodableAttachable(string: "stringly speaking")
      attachment = Test.Attachment(attachableValue, named: name)
    }

    try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { bytes in
      #expect(bytes.first == args.firstCharacter.asciiValue)
      let decodedStringValue = try args.decode(Data(bytes))
      #expect(decodedStringValue == "stringly speaking")
    }
  }

  @available(_uttypesAPI, *)
  @Test("Attach NSSecureCoding-conformant value but with a JSON type")
  func attachNSSecureCodingAsJSON() async throws {
    let attachableValue = MySecureCodingAttachable(string: "stringly speaking")
    let attachment = Test.Attachment(attachableValue, named: "loremipsum.json")
    #expect(throws: CocoaError.self) {
      try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { _ in }
    }
  }

  @available(_uttypesAPI, *)
  @Test("Attach NSSecureCoding-conformant value but with a nonsensical type")
  func attachNSSecureCodingAsNonsensical() async throws {
    let attachableValue = MySecureCodingAttachable(string: "stringly speaking")
    let attachment = Test.Attachment(attachableValue, named: "loremipsum.gif")
    #expect(throws: CocoaError.self) {
      try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { _ in }
    }
  }
#endif

#if canImport(UniformTypeIdentifiers)
  @available(_uttypesAPI, *)
  @Test func attachValueWithUTType() async {
    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachableValue = MyAttachable(string: "<!doctype html>")
        Test.Attachment(attachableValue, named: "loremipsum", as: .plainText).attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "loremipsum.txt")
        valueAttached()
      }
    }
  }

  @available(_uttypesAPI, *)
  @Test func attachSendableValueWithUTType() async {
    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachableValue = MySendableAttachable(string: "<!doctype html>")
        Test.Attachment(attachableValue, named: "loremipsum", as: .plainText).attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "loremipsum.txt")
        valueAttached()
      }
    }
  }

  @available(_uttypesAPI, *)
  @Test func overridingContentType() {
    // Explicitly passing a type modifies the preferred name. Note it's expected
    // that we preserve the original extension as this is the behavior of the
    // underlying UTType API (tries to be non-destructive to user input.)
    do {
      let attachableValue = MySendableAttachable(string: "<!doctype html>")
      let attachment = Test.Attachment(attachableValue, named: "loremipsum.txt", as: .html)
      #expect(attachment.preferredName == "loremipsum.txt.html")
    }
  }
#endif
}

extension AttachmentTests {
  @Suite("Built-in conformances")
  struct BuiltInConformances {
    func test(_ value: borrowing some Test.Attachable & ~Copyable) throws {
      #expect(value.estimatedAttachmentByteCount == 6)
      let attachment = Test.Attachment(value)
      try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { buffer in
        #expect(buffer.elementsEqual("abc123".utf8))
        #expect(buffer.count == 6)
      }
    }

    @Test func uint8Array() throws {
      let value: [UInt8] = Array("abc123".utf8)
      try test(value)
    }

    @Test func uint8ContiguousArray() throws {
      let value: ContiguousArray<UInt8> = ContiguousArray("abc123".utf8)
      try test(value)
    }

    @Test func uint8ArraySlice() throws {
      let value: ArraySlice<UInt8> = Array("abc123".utf8)[...]
      try test(value)
    }

    @Test func uint8UnsafeBufferPointer() throws {
      let value: [UInt8] = Array("abc123".utf8)
      try value.withUnsafeBufferPointer { value in
        try test(value)
      }
    }

    @Test func uint8UnsafeMutableBufferPointer() throws {
      var value: [UInt8] = Array("abc123".utf8)
      try value.withUnsafeMutableBufferPointer { value in
        try test(value)
      }
    }

    @Test func unsafeRawBufferPointer() throws {
      let value: [UInt8] = Array("abc123".utf8)
      try value.withUnsafeBytes { value in
        try test(value)
      }
    }

    @Test func unsafeMutableRawBufferPointer() throws {
      var value: [UInt8] = Array("abc123".utf8)
      try value.withUnsafeMutableBytes { value in
        try test(value)
      }
    }

    @Test func string() throws {
      let value = "abc123"
      try test(value)
    }

    @Test func substring() throws {
      let value: Substring = "abc123"[...]
      try test(value)
    }

#if canImport(Foundation)
    @Test func data() throws {
      let value = try #require("abc123".data(using: .utf8))
      try test(value)
    }

    @Test func contiguousBytesCollection() throws {
      let value = MyContiguousCollectionAttachable(string: "abc123")
      try test(value)
    }
#endif
  }
}

// MARK: - Fixtures

struct MyAttachable: Test.Attachable, ~Copyable {
  var string: String
  var errorToThrow: (any Error)?

  func withUnsafeBufferPointer<R>(for attachment: borrowing Testing.Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    if let errorToThrow {
      throw errorToThrow
    }

    var string = string
    return try string.withUTF8 { buffer in
      try body(.init(buffer))
    }
  }
}

@available(*, unavailable)
extension MyAttachable: Sendable {}

struct MySendableAttachable: Test.Attachable, Sendable {
  var string: String

  func withUnsafeBufferPointer<R>(for attachment: borrowing Testing.Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var string = string
    return try string.withUTF8 { buffer in
      try body(.init(buffer))
    }
  }
}

struct MySendableAttachableWithDefaultByteCount: Test.Attachable, Sendable {
  var string: String

  func withUnsafeBufferPointer<R>(for attachment: borrowing Testing.Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var string = string
    return try string.withUTF8 { buffer in
      try body(.init(buffer))
    }
  }
}

#if canImport(Foundation)
struct MyCodableAttachable: Codable, Test.Attachable, Sendable {
  var string: String
}

final class MySecureCodingAttachable: NSObject, NSSecureCoding, Test.Attachable, Sendable {
  let string: String

  init(string: String) {
    self.string = string
  }

  static var supportsSecureCoding: Bool {
    true
  }

  func encode(with coder: NSCoder) {
    coder.encode(string, forKey: "string")
  }

  required init?(coder: NSCoder) {
    string = (coder.decodeObject(of: NSString.self, forKey: "string") as? String) ?? ""
  }
}

struct MyContiguousCollectionAttachable: Collection, ContiguousBytes, Test.Attachable {
  private var _utf8: String.UTF8View

  var string: String {
    get {
      String(_utf8)
    }
    set {
      _utf8 = newValue.utf8
    }
  }

  init(string: String) {
    _utf8 = string.utf8
  }

  var startIndex: String.UTF8View.Index {
    _utf8.startIndex
  }

  var endIndex: String.UTF8View.Index {
    _utf8.endIndex
  }

  subscript(position: String.UTF8View.Index) -> UInt8 {
    _utf8[position]
  }

  func index(after i: String.UTF8View.Index) -> String.UTF8View.Index {
    _utf8.index(after: i)
  }

  func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    let result = try _utf8.withContiguousStorageIfAvailable { buffer in
      try body(.init(buffer))
    }
    return try result ?? Array(_utf8).withUnsafeBytes(body)
  }
}
#endif
