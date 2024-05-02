//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing
#if SWT_BUILDING_WITH_CMAKE
@_implementationOnly import _TestingInternals
#else
private import _TestingInternals
#endif

#if !SWT_NO_FILE_IO
// NOTE: we don't run these tests on iOS (etc.) because processes on those
// platforms are sandboxed and do not have arbitrary filesystem access.
#if os(macOS) || os(Linux) || os(Windows)
@Suite("FileHandle Tests")
struct FileHandleTests {
  // FileHandle is non-copyable, so it cannot yet be used as a test parameter.
  func canGet(_ fileHandle: borrowing FileHandle) {
    // This test function doesn't really do much other than check that the
    // standard I/O files can be accessed.
    fileHandle.withUnsafeCFILEHandle { fileHandle in
      #expect(EOF != feof(fileHandle))
    }
  }

  @Test("Can get stdout")
  func canGetStdout() {
    canGet(.stdout)
  }

  @Test("Can get stderr")
  func canGetStderr() {
    canGet(.stderr)
  }

  @Test("Can get file descriptor")
  func fileDescriptor() throws {
    let fileHandle = try FileHandle.temporary()
    try fileHandle.withUnsafePOSIXFileDescriptor { fd in
      try #require(fd != nil)
    }
  }

#if os(Windows)
  @Test("Can get Windows file HANDLE")
  func fileHANDLE() throws {
    let fileHandle = try FileHandle.temporary()
    try fileHandle.withUnsafeWindowsHANDLE { handle in
      try #require(handle != nil)
    }
  }
#endif

  @Test("Can write to a file")
  func canWrite() throws {
    try withTemporaryPath { path in
      let fileHandle = try FileHandle(forWritingAtPath: path)
      try fileHandle.write([0, 1, 2, 3, 4, 5])
      try fileHandle.write("Hello world!")
    }
  }

  @Test("Can read from a file")
  func canRead() throws {
    let bytes: [UInt8] = (0 ..< 8192).map { _ in
      UInt8.random(in: .min ... .max)
    }
    try withTemporaryPath { path in
      do {
        let fileHandle = try FileHandle(forWritingAtPath: path)
        try fileHandle.write(bytes)
      }
      let fileHandle = try FileHandle(forReadingAtPath: path)
      let bytes2 = try fileHandle.readToEnd()
      #expect(bytes == bytes2)
    }
  }

  @Test("Cannot write bytes to a read-only file")
  func cannotWriteBytesToReadOnlyFile() throws {
    let fileHandle = try FileHandle.null(mode: "rb")
    #expect(throws: CError.self) {
      try fileHandle.write([0, 1, 2, 3, 4, 5])
    }
  }

  @Test("Cannot write string to a read-only file")
  func cannotWriteStringToReadOnlyFile() throws {
    let fileHandle = try FileHandle.null(mode: "rb")
    #expect(throws: CError.self) {
      try fileHandle.write("Impossible!")
    }
  }

#if !os(Windows)
  // Disabled on Windows because the equivalent of /dev/tty, CON, redirects
  // to stdout, but stdout may be any type of file, not just a TTY.
  @Test("Can recognize opened TTY")
  func isTTY() throws {
#if os(Windows)
    let fileHandle = try FileHandle(forWritingAtPath: "CON")
#else
    let oldTERM = Environment.variable(named: "TERM")
    Environment.setVariable("xterm", named: "TERM")
    defer {
      Environment.setVariable(oldTERM, named: "TERM")
    }

    var primary: CInt = 0
    var secondary: CInt = 0
    try #require(0 == openpty(&primary, &secondary, nil, nil, nil))
    close(secondary)
    let file = try #require(fdopen(primary, "wb"))
#endif
    let fileHandle = FileHandle(unsafeCFILEHandle: file, closeWhenDone: true)
    #expect(Bool(fileHandle.isTTY))
  }
#endif

  @Test("Can recognize opened pipe")
  func isPipe() throws {
#if os(Windows)
    var rHandle: HANDLE?
    var wHandle: HANDLE?
    try #require(CreatePipe(&rHandle, &wHandle, nil, 0))
    if let rHandle {
      CloseHandle(rHandle)
    }
    let fdWrite = _open_osfhandle(intptr_t(bitPattern: wHandle), 0)
    let file = try #require(_fdopen(fdWrite, "wb"))
#else
    var fds: [CInt] = [-1, -1]
    try #require(0 == pipe(&fds))
    try #require(fds[1] >= 0)
    close(fds[0])
    let file = try #require(fdopen(fds[1], "wb"))
#endif
    let fileHandle = FileHandle(unsafeCFILEHandle: file, closeWhenDone: true)
    #expect(Bool(fileHandle.isPipe))
  }

  @Test("/dev/null is not a TTY or pipe")
  func devNull() throws {
    let fileHandle = try FileHandle.null(mode: "wb")
    #expect(!Bool(fileHandle.isTTY))
    #expect(!Bool(fileHandle.isPipe))
  }

#if !os(Windows)
  // Disabled on Windows because it does not have the equivalent of
  // fmemopen(), so there is no need for this test.
  @Test("fmemopen()'ed file is not a TTY or pipe")
  func fmemopenedFile() throws {
    let file = try #require(fmemopen(nil, 1, "wb+"))
    let fileHandle = FileHandle(unsafeCFILEHandle: file, closeWhenDone: true)
    #expect(!Bool(fileHandle.isTTY))
    #expect(!Bool(fileHandle.isPipe))
  }
#endif
}

// MARK: - Fixtures

func withTemporaryPath<R>(_ body: (_ path: String) throws -> R) throws -> R {
  // NOTE: we are not trying to test mkstemp() here. We are trying to test the
  // capacity of FileHandle to open a file for reading or writing and we need a
  // temporary file to write to.
#if os(Windows)
  let path = try String(unsafeUninitializedCapacity: 1024) { buffer in
    try #require(0 == tmpnam_s(buffer.baseAddress!, buffer.count))
    return strnlen(buffer.baseAddress!, buffer.count)
  }
#else
  let path = appendPathComponent("file_named_\(UInt64.random(in: 0 ..< .max))", to: try temporaryDirectory())
#endif
  defer {
    _ = remove(path)
  }
  return try body(path)
}

extension FileHandle {
  static func temporary() throws -> FileHandle {
#if os(Windows)
    let tmpFile: SWT_FILEHandle = try {
      var file: SWT_FILEHandle?
      try #require(0 == tmpfile_s(&file))
      return file!
    }()
#else
    let tmpFile = try #require(tmpfile())
#endif
    return FileHandle(unsafeCFILEHandle: tmpFile, closeWhenDone: true)
  }

  static func null(mode: String) throws -> FileHandle {
#if os(Windows)
    try FileHandle(atPath: "NUL", mode: mode)
#else
    try FileHandle(atPath: "/dev/null", mode: mode)
#endif
  }
}
#endif

func temporaryDirectory() throws -> String {
#if SWT_TARGET_OS_APPLE
  try withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(PATH_MAX)) { buffer in
    if 0 != confstr(_CS_DARWIN_USER_TEMP_DIR, buffer.baseAddress, buffer.count) {
      return String(cString: buffer.baseAddress!)
    }
    return try #require(Environment.variable(named: "TMPDIR"))
  }
#elseif os(Linux)
  "/tmp"
#elseif os(Windows)
  try withUnsafeTemporaryAllocation(of: wchar_t.self, capacity: Int(MAX_PATH + 1)) { buffer in
    // NOTE: GetTempPath2W() was introduced in Windows 10 Build 20348.
    if 0 == GetTempPathW(DWORD(buffer.count), buffer.baseAddress) {
      throw Win32Error(rawValue: GetLastError())
    }
    return try #require(String.decodeCString(buffer.baseAddress, as: UTF16.self)?.result)
  }
#endif
}

#endif
