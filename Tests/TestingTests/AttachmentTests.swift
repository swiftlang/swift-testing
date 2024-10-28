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
  @Test func saveValue() {
    let attachableValue = MyAttachable(string: "<!doctype html>")
    let attachment = Test.Attachment(attachableValue, named: "AttachmentTests.saveValue.html")
    attachment.attach()
  }

#if !SWT_NO_FILE_IO
  func compare(_ attachableValue: borrowing MyAttachable, toContentsOfFileAtPath filePath: String) throws {
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
    let attachableValue = MyAttachable(string: "<!doctype html>")
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
      let attachableValue = MyAttachable(string: "<!doctype html>\(i)")
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
    let attachableValue = MyAttachable(string: "<!doctype html>")
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
    let attachableValue = MyAttachable(string: "<!doctype html>")
    let attachment = Test.Attachment(attachableValue, named: name)

    // Write the attachment to disk, then read it back.
    let filePath = try attachment.write(toFileInDirectoryAtPath: temporaryDirectoryPath())
    defer {
      remove(filePath)
    }
    try compare(attachableValue, toContentsOfFileAtPath: filePath)
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
