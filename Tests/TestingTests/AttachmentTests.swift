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

@Suite("Attachment Tests")
struct AttachmentTests {
  @Test func saveValue() throws {
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
    let filePath = try attachment.write(toFileInDirectoryAtPath: temporaryDirectory())
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
      let filePath = try attachment.write(toFileInDirectoryAtPath: temporaryDirectory(), appending: suffixes.next()!)
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
    let originalFilePath = try attachment.write(toFileInDirectoryAtPath: temporaryDirectory())
    defer {
      remove(originalFilePath)
    }

    // Write the attachment to disk, then read it back.
    let suffix = String(UInt64.random(in: 0 ..< .max), radix: 36)
    let filePath = try attachment.write(toFileInDirectoryAtPath: temporaryDirectory(), appending: suffix)
    defer {
      remove(filePath)
    }
    let fileName = try #require(filePath.split { $0 == "/" || $0 == #"\"# }.last)
    #expect(fileName == "loremipsum-\(suffix).tar.gz.gif.jpeg.html")
    try compare(attachableValue, toContentsOfFileAtPath: filePath)
  }

#if os(Windows)
  static let maximumNameCount = Int(_MAX_FNAME)
  static let reservedNames: [String] = {
    // Return the list of COM ports that are NOT configured (and so will fail
    // to open for writing.)
    (0...9).lazy
      .map { "COM\($0)" }
      .filter { !PathFileExistsA($0) }
  }()
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
    let filePath = try attachment.write(toFileInDirectoryAtPath: temporaryDirectory())
    defer {
      remove(filePath)
    }
    try compare(attachableValue, toContentsOfFileAtPath: filePath)
  }

  @Test func fileSystemPathIsSetAfterWritingViaEventHandler() async throws {
    let attachableValue = MySendableAttachable(string: "<!doctype html>")
    try await confirmation("Attachment detected") { valueAttached in
      var configuration = Configuration()
      configuration.attachmentsPath = try temporaryDirectory()
      configuration.eventHandler = { event, _ in
        guard case let .valueAttached(attachment, _) = event.kind else {
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

      await Test {
        let attachment = Test.Attachment(attachableValue, named: "loremipsum.html")
        attachment.attach()
      }.run(configuration: configuration)
    }
  }
#endif

  @Test func attachValue() async {
    await confirmation("Attachment detected") { valueAttached in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        guard case let .valueAttached(attachment, _) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "loremipsum")
        valueAttached()
      }

      await Test {
        let attachableValue = MyAttachable(string: "<!doctype html>")
        Test.Attachment(attachableValue, named: "loremipsum").attach()
      }.run(configuration: configuration)
    }
  }

  @Test func attachSendableValue() async {
    await confirmation("Attachment detected") { valueAttached in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        guard case let .valueAttached(attachment, _) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "loremipsum")
        valueAttached()

        #expect(throws: Never.self) {
          let attachableValue = try #require(attachment.attachableValue as? MySendableAttachable)
          #expect(attachableValue.string == "<!doctype html>")
        }
      }

      await Test {
        let attachableValue = MySendableAttachable(string: "<!doctype html>")
        Test.Attachment(attachableValue, named: "loremipsum").attach()
      }.run(configuration: configuration)
    }
  }

  @Test func issueRecordedWhenAttachingNonSendableValueThatThrows() async {
    await confirmation("Attachment detected", expectedCount: 0) { valueAttached in
      await confirmation("Issue recorded") { issueRecorded in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case .valueAttached = event.kind {
            valueAttached()
          } else if case let .issueRecorded(issue) = event.kind,
                    case let .valueAttachmentFailed(error) = issue.kind,
                    error is MyError {
            issueRecorded()
          }
        }

        await Test {
          var attachableValue = MyAttachable(string: "<!doctype html>")
          attachableValue.errorToThrow = MyError()
          Test.Attachment(attachableValue, named: "loremipsum").attach()
        }.run(configuration: configuration)
      }
    }
  }
}

extension AttachmentTests {
  @Suite("Built-in conformances")
  struct BuiltInConformances {
    func test(_ value: some Test.Attachable) throws {
      #expect(value.estimatedAttachmentByteCount == 6)
      let attachment = Test.Attachment(value)
      try attachment.withUnsafeBufferPointer { buffer in
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
  }

  @Test func attachmentMetadata() throws {
    let attachableValue = MySendableAttachableWithMetadata(string: "abc123")
    let attachment = Test.Attachment(attachableValue, metadata: ["abc123": 456])
    let metadata = try #require(attachment.metadata)
    #expect(metadata[attachableValue.string] == 456)

    let attachmentCopy = Test.Attachment<Test.AnyAttachable>(attachment)
    let metadata2 = try #require(attachmentCopy.metadata as? [String: Int])
    #expect(metadata == metadata2)
  }
}

// MARK: - Fixtures

struct MyAttachable: Test.Attachable, ~Copyable {
  var string: String
  var errorToThrow: (any Error)?

  func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
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

  func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    #expect(attachment.attachableValue.string == string)
    var string = string
    return try string.withUTF8 { buffer in
      try body(.init(buffer))
    }
  }
}

struct MySendableAttachableWithDefaultByteCount: Test.Attachable, Sendable {
  var string: String

  func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var string = string
    return try string.withUTF8 { buffer in
      try body(.init(buffer))
    }
  }
}

struct MySendableAttachableWithMetadata: Test.Attachable, Sendable {
  var string: String

  typealias AttachmentMetadata = [String: Int]

  func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var string = string
    return try string.withUTF8 { buffer in
      try body(.init(buffer))
    }
  }
}
