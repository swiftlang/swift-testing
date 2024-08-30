//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

#if !SWT_NO_FILE_IO
/// A type representing a file handle.
///
/// Instances of this type abstract away the C `FILE *` type for Swift.
///
/// Whether or not a particular C file handle is safe to use concurrently is
/// platform- and file-specific. The testing library assumes that the standard
/// I/O file handles are generally concurrency-safe as implemented on supported
/// platforms.
///
/// This type is not part of the public interface of the testing library.
struct FileHandle: ~Copyable, Sendable {
  /// The underlying C file handle.
  private nonisolated(unsafe) var _fileHandle: SWT_FILEHandle

  /// Whether or not to close `_fileHandle` when this instance is deinitialized.
  private var _closeWhenDone: Bool

  // The value of stdout or stderr might change over time on some platforms, so
  // these properties need to be computed each time. Fortunately, creating a new
  // instance of this type from an existing C file handle is cheap.

  /// The C standard output stream.
  static var stdout: Self {
    Self(unsafeCFILEHandle: swt_stdout(), closeWhenDone: false)
  }

  /// The C standard error stream.
  static var stderr: Self {
    Self(unsafeCFILEHandle: swt_stderr(), closeWhenDone: false)
  }

  /// Initialize an instance of this type by opening a file at the given path
  /// with the given mode.
  ///
  /// - Parameters:
  ///   - path: The path to open.
  ///   - mode: The mode to open `path` with, such as `"wb"`.
  ///
  /// - Throws: Any error preventing the stream from being opened.
  init(atPath path: String, mode: String) throws {
#if os(Windows)
    // Windows deprecates fopen() as insecure, so call _wfopen_s() instead.
    let fileHandle = try path.withCString(encodedAs: UTF16.self) { path in
      try mode.withCString(encodedAs: UTF16.self) { mode in
        var file: SWT_FILEHandle?
        let result = _wfopen_s(&file, path, mode)
        guard let file, result == 0 else {
          throw CError(rawValue: result)
        }
        return file
      }
    }
#else
    guard let fileHandle = fopen(path, mode) else {
      throw CError(rawValue: swt_errno())
    }
#endif
    self.init(unsafeCFILEHandle: fileHandle, closeWhenDone: true)
  }

  /// Initialize an instance of this type to read from the given path.
  ///
  /// - Parameters:
  ///   - path: The path to read from.
  ///
  /// - Throws: Any error preventing the stream from being opened.
  init(forReadingAtPath path: String) throws {
    try self.init(atPath: path, mode: "rb")
  }

  /// Initialize an instance of this type to write to the given path.
  ///
  /// - Parameters:
  ///   - path: The path to write to.
  ///
  /// - Throws: Any error preventing the stream from being opened.
  init(forWritingAtPath path: String) throws {
#if os(Windows)
    // Special-case CONOUT$ to map to stdout. This way, if somebody specifies
    // CONOUT$ as the target path for XML or JSON output from `swift test`,
    // output will be correctly interleaved with writes to `stdout`. If we don't
    // do this, the file will open successfully but will be opened in text mode
    // (despite us asking for binary mode), will wrap at the virtual console's
    // column limit, and won't share a file lock with the C `stdout` handle.
    //
    // To our knowledge, this sort of special-casing is not required on
    // POSIX-like platforms (i.e. when opening "/dev/stdout"), but it can be
    // adapted for use there if some POSIX-like platform does need it.
    if path == "CONOUT$" {
      self = .stdout
      return
    }
#endif
    try self.init(atPath: path, mode: "wb")
  }

  /// Initialize an instance of this type with an existing C file handle.
  ///
  /// - Parameters:
  ///   - fileHandle: The C file handle to wrap. The caller is responsible for
  ///     ensuring that this file handle is open in the expected mode and that
  ///     another part of the system won't close it.
  ///   - closeWhenDone: Whether or not to close `fileHandle` when the resulting
  ///     instance is deinitialized. The caller is responsible for ensuring that
  ///     there are no other references to `fileHandle` when passing `true`.
  init(unsafeCFILEHandle fileHandle: SWT_FILEHandle, closeWhenDone: Bool) {
    _fileHandle = fileHandle
    _closeWhenDone = closeWhenDone
  }

  deinit {
    if _closeWhenDone {
      fclose(_fileHandle)
    }
  }

  /// Call a function and pass the underlying C file handle to it.
  ///
  /// - Parameters:
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  ///
  /// Use this function when calling C I/O interfaces such as `fputs()` on the
  /// underlying C file handle.
  borrowing func withUnsafeCFILEHandle<R>(_ body: (SWT_FILEHandle) throws -> R) rethrows -> R {
    try body(_fileHandle)
  }

  /// Call a function and pass the underlying POSIX file descriptor to it.
  ///
  /// - Parameters:
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  ///
  /// Use this function when calling interfaces on the underlying C file handle
  /// that require a file descriptor instead of the standard `FILE *`
  /// representation. If the file handle cannot be converted to a file
  /// descriptor, `nil` is passed to `body`.
  borrowing func withUnsafePOSIXFileDescriptor<R>(_ body: (CInt?) throws -> R) rethrows -> R {
    try withUnsafeCFILEHandle { handle in
#if SWT_TARGET_OS_APPLE || os(Linux) || os(WASI)
      let fd = fileno(handle)
#elseif os(Windows)
      let fd = _fileno(handle)
#else
#warning("Platform-specific implementation missing: cannot get file descriptor from a file handle")
      let fd: CInt = -1
#endif

      if Bool(fd >= 0) {
        return try body(fd)
      }
      return try body(nil)
    }
  }

#if os(Windows)
  /// Call a function and pass the underlying Windows file handle to it.
  ///
  /// - Parameters:
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  ///
  /// Use this function when calling interfaces on the underlying C file handle
  /// that require the file's `HANDLE` representation instead of the standard
  /// `FILE *` representation. If the file handle cannot be converted to a
  /// Windows handle, `nil` is passed to `body`.
  borrowing func withUnsafeWindowsHANDLE<R>(_ body: (HANDLE?) throws -> R) rethrows -> R {
    try withUnsafePOSIXFileDescriptor { fd in
      guard let fd else {
        return try body(nil)
      }
      var handle = HANDLE(bitPattern: _get_osfhandle(fd))
      if handle == INVALID_HANDLE_VALUE || handle == .init(bitPattern: -2) {
        handle = nil
      }
      return try body(handle)
    }
  }
#endif

  /// Call a function while holding the file handle's lock.
  ///
  /// - Parameters:
  ///   - body: A function to call.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  ///
  /// This function uses `flockfile()` and `funlockfile()` to synchronize access
  /// to the underlying file. It can be used when, for example, write operations
  /// are split across multiple calls but must not be interleaved with writes on
  /// other threads.
  borrowing func withLock<R>(_ body: () throws -> R) rethrows -> R {
    try withUnsafeCFILEHandle { handle in
#if SWT_TARGET_OS_APPLE || os(Linux)
      flockfile(handle)
      defer {
        funlockfile(handle)
      }
#elseif os(Windows)
      _lock_file(handle)
      defer {
        _unlock_file(handle)
      }
#elseif os(WASI)
      // No file locking on WASI yet.
#else
#warning("Platform-specific implementation missing: cannot lock a file handle")
#endif
      return try body()
    }
  }
}

// MARK: - Reading

extension FileHandle {
  /// Read to the end of the file handle.
  ///
  /// - Returns: A copy of the contents of the file handle starting at the
  ///   current offset and ending at the end of the file.
  ///
  /// - Throws: Any error that occurred while reading the file.
  func readToEnd() throws -> [UInt8] {
    var result = [UInt8]()

    // If possible, reserve enough space in the resulting buffer to contain
    // the contents of the file being read.
    var size: Int?
#if SWT_TARGET_OS_APPLE || os(Linux) || os(WASI)
    withUnsafePOSIXFileDescriptor { fd in
      var s = stat()
      if let fd, 0 == fstat(fd, &s) {
        size = Int(exactly: s.st_size)
      }
    }
#elseif os(Windows)
    withUnsafeWindowsHANDLE { handle in
      var liSize = LARGE_INTEGER(QuadPart: 0)
      if let handle, GetFileSizeEx(handle, &liSize) {
        size = Int(exactly: liSize.QuadPart)
      }
    }
#endif
    if let size, size > 0 {
      result.reserveCapacity(size)
    }

    try withUnsafeCFILEHandle { file in
      try withUnsafeTemporaryAllocation(byteCount: 1024, alignment: 1) { buffer in
        repeat {
          let countRead = fread(buffer.baseAddress!, 1, buffer.count, file)
          if 0 != ferror(file) {
            throw CError(rawValue: swt_errno())
          }
          if countRead > 0 {
            let endIndex = buffer.index(buffer.startIndex, offsetBy: countRead)
            result.append(contentsOf: buffer[..<endIndex])
          }
        } while 0 == feof(file)
      }
    }

    return result
  }
}

// MARK: - Writing

extension FileHandle {
  /// Write a sequence of bytes to this file handle.
  ///
  /// - Parameters:
  ///   - bytes: The bytes to write. This untyped buffer is interpreted as a
  ///     sequence of `UInt8` values.
  ///   - flushAfterward: Whether or not to flush the file (with `fflush()`)
  ///     after writing. If `true`, `fflush()` is called even if an error
  ///     occurred while writing.
  ///
  /// - Throws: Any error that occurred while writing `bytes`. If an error
  ///   occurs while flushing the file, it is not thrown.
  func write(_ bytes: UnsafeBufferPointer<UInt8>, flushAfterward: Bool = true) throws {
    try withUnsafeCFILEHandle { file in
      defer {
        if flushAfterward {
          _ = fflush(file)
        }
      }

      let countWritten = fwrite(bytes.baseAddress!, MemoryLayout<UInt8>.stride, bytes.count, file)
      if countWritten < bytes.count {
        throw CError(rawValue: swt_errno())
      }
    }
  }

  /// Write a sequence of bytes to this file handle.
  ///
  /// - Parameters:
  ///   - bytes: The bytes to write.
  ///   - flushAfterward: Whether or not to flush the file (with `fflush()`)
  ///     after writing. If `true`, `fflush()` is called even if an error
  ///     occurred while writing.
  ///
  /// - Throws: Any error that occurred while writing `bytes`. If an error
  ///   occurs while flushing the file, it is not thrown.
  ///
  /// - Precondition: `bytes` must provide contiguous storage.
  func write(_ bytes: some Sequence<UInt8>, flushAfterward: Bool = true) throws {
    let hasContiguousStorage: Void? = try bytes.withContiguousStorageIfAvailable { bytes in
      try write(bytes, flushAfterward: flushAfterward)
    }
    precondition(hasContiguousStorage != nil, "byte sequence must provide contiguous storage: \(bytes)")
  }

  /// Write a sequence of bytes to this file handle.
  ///
  /// - Parameters:
  ///   - bytes: The bytes to write. This untyped buffer is interpreted as a
  ///     sequence of `UInt8` values.
  ///   - flushAfterward: Whether or not to flush the file (with `fflush()`)
  ///     after writing. If `true`, `fflush()` is called even if an error
  ///     occurred while writing.
  ///
  /// - Throws: Any error that occurred while writing `bytes`. If an error
  ///   occurs while flushing the file, it is not thrown.
  func write(_ bytes: UnsafeRawBufferPointer, flushAfterward: Bool = true) throws {
    try bytes.withMemoryRebound(to: UInt8.self) { bytes in
      try write(bytes, flushAfterward: flushAfterward)
    }
  }

  /// Write a string to this file handle.
  ///
  /// - Parameters:
  ///   - string: The string to write.
  ///   - flushAfterward: Whether or not to flush the file (with `fflush()`)
  ///     after writing. If `true`, `fflush()` is called even if an error
  ///     occurred while writing.
  ///
  /// - Throws: Any error that occurred while writing `string`. If an error
  ///   occurs while flushing the file, it is not thrown.
  ///
  /// `string` is converted to a UTF-8 C string (UTF-16 on Windows) and written
  /// to this file handle.
  func write(_ string: String, flushAfterward: Bool = true) throws {
    try withUnsafeCFILEHandle { file in
      defer {
        if flushAfterward {
          _ = fflush(file)
        }
      }

      try string.withCString { string in
        if EOF == fputs(string, file) {
          throw CError(rawValue: swt_errno())
        }
      }
    }
  }
}

// MARK: - Attributes

extension FileHandle {
  /// Is this file handle a TTY or PTY?
  var isTTY: Bool {
#if SWT_TARGET_OS_APPLE || os(Linux) || os(WASI)
    // If stderr is a TTY and TERM is set, that's good enough for us.
    withUnsafePOSIXFileDescriptor { fd in
      if let fd, 0 != isatty(fd), let term = Environment.variable(named: "TERM"), !term.isEmpty {
        return true
      }
      return false
    }
#elseif os(Windows)
    // If there is a console buffer associated with the file handle, then it's a
    // console.
    return withUnsafeWindowsHANDLE { handle in
      guard let handle else {
        return false
      }
      var screenBufferInfo = CONSOLE_SCREEN_BUFFER_INFO()
      return GetConsoleScreenBufferInfo(handle, &screenBufferInfo)
    }
#else
#warning("Platform-specific implementation missing: cannot tell if a file is a TTY")
    return false
#endif
  }

  /// Is this file handle a pipe or FIFO?
  var isPipe: Bool {
#if SWT_TARGET_OS_APPLE || os(Linux) || os(WASI)
    withUnsafePOSIXFileDescriptor { fd in
      guard let fd else {
        return false
      }
      var statStruct = stat()
      return (0 == fstat(fd, &statStruct) && swt_S_ISFIFO(statStruct.st_mode))
    }
#elseif os(Windows)
    return withUnsafeWindowsHANDLE { handle in
      guard let handle else {
        return false
      }
      return FILE_TYPE_PIPE == GetFileType(handle)
    }
#else
#warning("Platform-specific implementation missing: cannot tell if a file is a pipe")
    return false
#endif
  }
}

// MARK: - General path utilities

/// Append a path component to a path.
///
/// - Parameters:
///   - pathComponent: The path component to append.
///   - path: The path to which `pathComponent` should be appended.
///
/// - Returns: The full path to `pathComponent`, or `nil` if the resulting
///   string could not be created.
func appendPathComponent(_ pathComponent: String, to path: String) -> String {
#if os(Windows)
  path.withCString(encodedAs: UTF16.self) { path in
    pathComponent.withCString(encodedAs: UTF16.self) { pathComponent in
      withUnsafeTemporaryAllocation(of: wchar_t.self, capacity: (wcslen(path) + wcslen(pathComponent)) * 2 + 1) { buffer in
        _ = wcscpy_s(buffer.baseAddress, buffer.count, path)
        _ = PathCchAppendEx(buffer.baseAddress, buffer.count, pathComponent, ULONG(PATHCCH_ALLOW_LONG_PATHS.rawValue))
        return (String.decodeCString(buffer.baseAddress, as: UTF16.self)?.result)!
      }
    }
  }
#else
  "\(path)/\(pathComponent)"
#endif
}
#endif
