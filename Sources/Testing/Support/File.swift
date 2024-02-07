//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_FILE_IO
internal import TestingInternals

struct File: @unchecked Sendable, ~Copyable {
  private var _handle: SWT_FILEHandle
  private var _closeWhenDone: Bool

  /// The standard error stream, equivalent to `stderr`.
  static let standardError = Self(fileHandle: swt_stderr(), closeWhenDone: false)

  /// Initialize an instance of this type with an existing C `FILE *` handle.
  ///
  /// - Parameters:
  ///   - fileHandle: The existing file handle. This file handle must already be
  ///     open in the mode that the calling code requires.
  ///   - closeWhenDone: Whether or not to pass `fileHandle` to `fclose()` when
  ///     this instance is deinitialized.
  ///
  /// If `closeWhenDone` is `true`, the resulting instance takes ownership of
  /// `fileHandle`. If `closeWhenDone` is `false`, the calling code is
  /// responsible for managing the lifetime of the file handle.
  init(fileHandle: SWT_FILEHandle, closeWhenDone: Bool) {
    _handle = fileHandle
    _closeWhenDone = closeWhenDone
  }

  /// Open a file at the given path.
  ///
  /// - Parameters:
  ///   - path: The path at which to open the file.
  ///   - mode: The mode with which to open the file. For valid values, see the
  ///     `fopen()` function from the C standard library.
  ///
  /// - Returns: A new instance of this type representing a file at `path`
  ///   opened in the requested mode.
  ///
  /// - Throws: Any error that occurs when trying to open the file.
  static func open(atPath path: String, mode: String) throws -> Self {
#if os(Windows)
    let handle = try path.withCString(encodedAs: UTF16.self) { path in
      try mode.withCString(encodedAs: UTF16.self) { mode in
        var file: SWT_FILEHandle?
        let result = _wfopen_s(&file, path, mode)
        guard result == 0 else {
          throw CError(rawValue: result)
        }
        return file
      }
    }
#else
    let handle = try path.withCString { path in
      try mode.withCString { mode in
        guard let file = fopen(path, mode) else {
          throw CError(rawValue: swt_errno())
        }
        return file
      }
    }
#endif
    return Self(fileHandle: handle, closeWhenDone: true)
  }

  deinit {
    if _closeWhenDone {
      fclose(_handle)
    }
  }

  /// Get the underlying C `FILE *` handle.
  ///
  /// - Parameters:
  ///   - body: The function to invoke. The underlying C `FILE *` pointer is
  ///     passed to this function and is only valid until it returns or throws.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  borrowing func withUnsafeFILEHandle<R>(_ body: (SWT_FILEHandle) throws -> R) rethrows -> R {
    try body(_handle)
  }
}

// MARK: - Platform-specific properties

extension File {
  /// Whether or not this file is capable of accepting and rendering ANSI escape
  /// codes.
  var supportsANSIEscapeCodes: Bool {
    // Respect the NO_COLOR environment variable. SEE: https://www.no-color.org
    if let noColor = Environment.variable(named: "NO_COLOR"), !noColor.isEmpty {
      return false
    }

    // Determine if this file appears to write to a Terminal window capable of
    // accepting ANSI escape codes.
    if isTerminal {
      return true
    }

    // If the file is a pipe, assume the other end is using it to forward output
    // from this process to its own stderr file. This is how `swift test`
    // invokes the testing library, for example.
    if isPipe {
      return true
    }

    return false
  }

  /// Whether or not this file writes to (or reads from) a terminal as
  /// determined by the operating system.
  var isTerminal: Bool {
    withUnsafeFILEHandle { file in
#if SWT_TARGET_OS_APPLE || os(Linux)
      // If this file is a TTY and TERM is set, that's good enough for us.
      let fd = fileno(file)
      if fd >= 0 && 0 != isatty(fd),
         let term = Environment.variable(named: "TERM"),
         !term.isEmpty && term != "dumb" {
        return true
      }
#elseif os(Windows)
      // If there is a console buffer associated with this file, then it's a
      // console.
      let fd = _fileno(file)
      if fd >= 0, let winFileHandle = HANDLE(bitPattern: _get_osfhandle(fd)) {
        var screenBufferInfo = CONSOLE_SCREEN_BUFFER_INFO()
        return GetConsoleScreenBufferInfo(winFileHandle, &screenBufferInfo)
      }
#endif
      return false
    }
  }

  /// Whether or not this file is a pipe (or FIFO.)
  var isPipe: Bool {
    withUnsafeFILEHandle { file in
#if SWT_TARGET_OS_APPLE || os(Linux)
      let fd = fileno(file)
      var statStruct = stat()
      if fd >= 0 && 0 == fstat(fd, &statStruct) && swt_S_ISFIFO(statStruct.st_mode) {
        return true
      }
#elseif os(Windows)
      let fd = _fileno(file)
      if fd >= 0, let winFileHandle = HANDLE(bitPattern: _get_osfhandle(fd)) {
        return FILE_TYPE_PIPE == GetFileType(stderrHandle)
      }
#endif
      return false
    }
  }
}

/// Whether or not the system terminal claims to support 256-color ANSI escape
/// codes.
var terminalSupports256ColorANSIEscapeCodes: Bool {
#if SWT_TARGET_OS_APPLE || os(Linux)
  if let termVariable = Environment.variable(named: "TERM") {
    return strstr(termVariable, "256") != nil
  }
  return false
#elseif os(Windows)
  // Windows does not set the "TERM" variable, so assume it supports 256-color
  // ANSI escape codes.
  true
#endif
}
#endif
