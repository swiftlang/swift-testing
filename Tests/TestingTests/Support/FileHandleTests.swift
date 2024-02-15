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
private import TestingInternals

#if !SWT_NO_FILE_IO
// NOTE: we don't run these tests on iOS (etc.) because processes on those
// platforms are sandboxed and do not have arbitrary filesystem access.
#if os(macOS) || os(Linux) || os(Windows)
@Suite("FileHandle Tests")
struct FileHandleTests {
  @Test("Can get file descriptor")
  func fileDescriptor() throws {
    #if os(Windows)
    let tmpFile: SWT_FILEHandle = try {
      var file: SWT_FILEHandle?
      try #require(0 == tmpfile_s(&file))
      return file!
    }()
    #else
    let tmpFile = try #require(tmpfile())
    #endif
    let fileHandle = FileHandle(unsafeCFILEHandle: tmpFile, closeWhenDone: true)
    try fileHandle.withUnsafePOSIXFileDescriptor { fd in
      try #require(fd != nil)
    }
  }

#if os(Windows)
  @Test("Can get Windows file HANDLE")
  func fileHANDLE() throws {
    let tmpFile: SWT_FILEHandle = try {
      var file: SWT_FILEHandle?
      try #require(0 == tmpfile_s(&file))
      return file!
    }()
    let fileHandle = FileHandle(unsafeCFILEHandle: tmpFile, closeWhenDone: true)
    try fileHandle.withUnsafeWindowsHANDLE { handle in
      try #require(handle != nil)
    }
  }
#endif

  @Test("Can write to a file")
  func canWrite() throws {
    // NOTE: we are not trying to test mkstemp() here. We are trying to test the
    // capacity of FileHandle to open a file for writing, and need a temporary
    // file to write to.
    let fileName = "can_write_to_file_\(UInt64.random(in: 0 ..< .max))"
#if os(Windows)
    let cPath = try #require(_tempnam("c:\\tmp", fileName))
    defer {
      free(cPath)
    }
    let path = String(cString: cPath)
#else
    let path = "/tmp/\(fileName)"
#endif
    defer {
      remove(path)
    }
    let fileHandle = try FileHandle(forWritingAtPath: path)
    fileHandle.withUnsafeCFILEHandle { file in
      #expect(EOF != fputs("Hello world!", file))
    }
  }

#if !os(Windows)
  // Disabled on Windows because the equivalent of /dev/null, CON, redirects
  // to stdout, but stdout may be any type of file, not just a TTY.
  @Test("Can recognize opened TTY")
  func isTTY() throws {
#if os(Windows)
    let file: SWT_FILEHandle = try {
      var file: SWT_FILEHandle?
      try #require(0 == fopen_s(&file, "CON", "wb"))
      return file!
    }()
#else
    let file = try #require(fopen("/dev/tty", "wb"))
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
#if os(Windows)
    let file: SWT_FILEHandle = try {
      var file: SWT_FILEHandle?
      try #require(0 == fopen_s(&file, "NUL", "wb"))
      return file!
    }()
#else
    let file = try #require(fopen("/dev/null", "wb"))
#endif
    let fileHandle = FileHandle(unsafeCFILEHandle: file, closeWhenDone: true)
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
#endif
#endif
