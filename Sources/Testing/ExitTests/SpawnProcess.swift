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

#if !SWT_NO_EXIT_TESTS
/// A platform-specific value identifying a process running on the current
/// system.
#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD)
typealias ProcessID = pid_t
#elseif os(Windows)
typealias ProcessID = HANDLE
#else
#warning("Platform-specific implementation missing: process IDs unavailable")
typealias ProcessID = Never
#endif

/// Spawn a process and wait for it to terminate.
///
/// - Parameters:
///   - executablePath: The path to the executable to spawn.
///   - arguments: The arguments to pass to the executable, not including the
///     executable path.
///   - environment: The environment block to pass to the executable.
///   - additionalFileHandles: A collection of file handles to inherit in the
///     child process.
///
/// - Returns: A value identifying the process that was spawned. The caller must
///   eventually pass this value to ``wait(for:)`` to avoid leaking system
///   resources.
///
/// - Throws: Any error that prevented the process from spawning or its exit
///   condition from being read.
func spawnExecutable(
  atPath executablePath: String,
  arguments: [String],
  environment: [String: String],
  additionalFileHandles: UnsafeBufferPointer<FileHandle> = .init(start: nil, count: 0)
) throws -> ProcessID {
  // Darwin and Linux differ in their optionality for the posix_spawn types we
  // use, so use this typealias to paper over the differences.
#if SWT_TARGET_OS_APPLE
  typealias P<T> = T?
#elseif os(Linux) || os(FreeBSD)
  typealias P<T> = T
#endif

#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD)
  return try withUnsafeTemporaryAllocation(of: P<posix_spawn_file_actions_t>.self, capacity: 1) { fileActions in
    guard 0 == posix_spawn_file_actions_init(fileActions.baseAddress!) else {
      throw CError(rawValue: swt_errno())
    }
    defer {
      _ = posix_spawn_file_actions_destroy(fileActions.baseAddress!)
    }

    return try withUnsafeTemporaryAllocation(of: P<posix_spawnattr_t>.self, capacity: 1) { attrs in
      guard 0 == posix_spawnattr_init(attrs.baseAddress!) else {
        throw CError(rawValue: swt_errno())
      }
      defer {
        _ = posix_spawnattr_destroy(attrs.baseAddress!)
      }

      // Do not forward standard I/O.
      _ = posix_spawn_file_actions_addopen(fileActions.baseAddress!, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
      _ = posix_spawn_file_actions_addopen(fileActions.baseAddress!, STDOUT_FILENO, "/dev/null", O_WRONLY, 0)
      _ = posix_spawn_file_actions_addopen(fileActions.baseAddress!, STDERR_FILENO, "/dev/null", O_WRONLY, 0)

#if os(Linux) || os(FreeBSD)
      var highestFD = CInt(0)
#endif
      for i in 0 ..< additionalFileHandles.count {
        try additionalFileHandles[i].withUnsafePOSIXFileDescriptor { fd in
          guard let fd else {
            throw SystemError(description: "A child process inherit a file handle without an associated file descriptor. Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
          }
#if SWT_TARGET_OS_APPLE
          _ = posix_spawn_file_actions_addinherit_np(fileActions.baseAddress!, fd)
#elseif os(Linux) || os(FreeBSD)
          highestFD = max(highestFD, fd)
#endif
        }
      }

#if SWT_TARGET_OS_APPLE
      // Close all other file descriptors open in the parent.
      _ = posix_spawnattr_setflags(attrs.baseAddress!, CShort(POSIX_SPAWN_CLOEXEC_DEFAULT))
#elseif os(Linux) || os(FreeBSD)
      // This platform doesn't have POSIX_SPAWN_CLOEXEC_DEFAULT, but we can at
      // least close all file descriptors higher than the highest inherited one.
      // We are assuming here that the caller didn't set FD_CLOEXEC on any of
      // these file descriptors.
      _ = swt_posix_spawn_file_actions_addclosefrom_np(fileActions.baseAddress!, highestFD + 1)
#else
#warning("Platform-specific implementation missing: cannot close unused file descriptors")
#endif

      var argv: [UnsafeMutablePointer<CChar>?] = [strdup(executablePath)]
      argv += arguments.lazy.map { strdup($0) }
      argv.append(nil)
      defer {
        for arg in argv {
          free(arg)
        }
      }

      var environ: [UnsafeMutablePointer<CChar>?] = environment.map { strdup("\($0.key)=\($0.value)") }
      environ.append(nil)
      defer {
        for environ in environ {
          free(environ)
        }
      }

      var pid = pid_t()
      guard 0 == posix_spawn(&pid, executablePath, fileActions.baseAddress!, attrs.baseAddress, argv, environ) else {
        throw CError(rawValue: swt_errno())
      }
      return pid
    }
  }
#elseif os(Windows)
  return try _withStartupInfoEx(attributeCount: 1) { startupInfo in
    // Forward the back channel's write end to the child process so that it can
    // send information back to us. Note that we don't keep the pipe open as
    // bidirectional, though we could if we find we need to in the future.
    let inheritedHandlesBuffer = UnsafeMutableBufferPointer<HANDLE?>.allocate(capacity: additionalFileHandles.count)
    defer {
      inheritedHandlesBuffer.deallocate()
    }
    for i in 0 ..< additionalFileHandles.count {
      try additionalFileHandles[i].withUnsafeWindowsHANDLE { handle in
        guard let handle else {
          throw SystemError(description: "A child process inherit a file handle without an associated Windows handle. Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
        }
        inheritedHandlesBuffer[i] = handle
      }
    }

    // Update the attribute list to hold the handle buffer.
    _ = UpdateProcThreadAttribute(
      startupInfo.pointee.lpAttributeList,
      0,
      swt_PROC_THREAD_ATTRIBUTE_HANDLE_LIST(),
      inheritedHandlesBuffer.baseAddress!,
      SIZE_T(MemoryLayout<HANDLE>.stride * inheritedHandlesBuffer.count),
      nil,
      nil
    )

    let commandLine = _escapeCommandLine(CollectionOfOne(executablePath) + arguments)
    let environ = environment.map { "\($0.key)=\($0.value)"}.joined(separator: "\0") + "\0\0"

    return try commandLine.withCString(encodedAs: UTF16.self) { commandLine in
      try environ.withCString(encodedAs: UTF16.self) { environ in
        var processInfo = PROCESS_INFORMATION()

        guard CreateProcessW(
          nil,
          .init(mutating: commandLine),
          nil,
          nil,
          true, // bInheritHandles
          DWORD(CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT | EXTENDED_STARTUPINFO_PRESENT),
          .init(mutating: environ),
          nil,
          startupInfo.pointer(to: \.StartupInfo)!,
          &processInfo
        ) else {
          throw Win32Error(rawValue: GetLastError())
        }
        _ = CloseHandle(processInfo.hThread)

        return processInfo.hProcess!
      }
    }
  }
#else
#warning("Platform-specific implementation missing: process spawning unavailable")
  throw SystemError(description: "Exit tests are unimplemented on this platform.")
#endif
}

// MARK: -

#if os(Windows)
/// Create a temporary instance of `STARTUPINFOEXW` to pass to
/// `CreateProcessW()`.
///
/// - Parameters:
///   - attributeCount: The number of attributes to make space for in the
///     resulting structure's attribute list.
///   - body: A function to invoke. A temporary, mutable pointer to an instance
///     of `STARTUPINFOEXW` is passed to this function.
///
/// - Returns: Whatever is returned by `body`.
///
/// - Throws: Whatever is thrown while creating the startup info structure or
///   its attribute list, or whatever is thrown by `body`.
private func _withStartupInfoEx<R>(attributeCount: Int = 0, _ body: (UnsafeMutablePointer<STARTUPINFOEXW>) throws -> R) throws -> R {
  // Initialize the startup info structure.
  var startupInfo = STARTUPINFOEXW()
  startupInfo.StartupInfo.cb = DWORD(MemoryLayout.size(ofValue: startupInfo))

  guard attributeCount > 0 else {
    return try body(&startupInfo)
  }

  // Initialize an attribute list of sufficient size for the specified number of
  // attributes. Alignment is a problem because LPPROC_THREAD_ATTRIBUTE_LIST is
  // an opaque pointer and we don't know the alignment of the underlying data.
  // We *should* use the alignment of C's max_align_t, but it is defined using a
  // C++ using statement on Windows and isn't imported into Swift. So, 16 it is.
  var attributeListByteCount = SIZE_T(0)
  _ = InitializeProcThreadAttributeList(nil, DWORD(attributeCount), 0, &attributeListByteCount)
  return try withUnsafeTemporaryAllocation(byteCount: Int(attributeListByteCount), alignment: 16) { attributeList in
    let attributeList = LPPROC_THREAD_ATTRIBUTE_LIST(attributeList.baseAddress!)
    guard InitializeProcThreadAttributeList(attributeList, DWORD(attributeCount), 0, &attributeListByteCount) else {
      throw Win32Error(rawValue: GetLastError())
    }
    defer {
      DeleteProcThreadAttributeList(attributeList)
    }
    startupInfo.lpAttributeList = attributeList

    return try body(&startupInfo)
  }
}

/// Construct an escaped command line string suitable for passing to
/// `CreateProcessW()`.
///
/// - Parameters:
///   - arguments: The arguments, including the executable path, to include in
///     the command line string.
///
/// - Returns: A command line string. This string can later be parsed with
///   `CommandLineToArgvW()`.
///
/// Windows processes are responsible for handling their own command-line
/// escaping. This function is adapted from the code in
/// swift-corelibs-foundation (see `quoteWindowsCommandLine()`) which was
/// itself adapted from code [published by Microsoft](https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way).
private func _escapeCommandLine(_ arguments: [String]) -> String {
  return arguments.lazy
    .map { arg in
      if !arg.contains(where: {" \t\n\"".contains($0)}) {
        return arg
      }

      var quoted = "\""
      var unquoted = arg.unicodeScalars
      while !unquoted.isEmpty {
        guard let firstNonBackslash = unquoted.firstIndex(where: { $0 != "\\" }) else {
          let backslashCount = unquoted.count
          quoted.append(String(repeating: "\\", count: backslashCount * 2))
          break
        }
        let backslashCount = unquoted.distance(from: unquoted.startIndex, to: firstNonBackslash)
        if (unquoted[firstNonBackslash] == "\"") {
          quoted.append(String(repeating: "\\", count: backslashCount * 2 + 1))
          quoted.append(String(unquoted[firstNonBackslash]))
        } else {
          quoted.append(String(repeating: "\\", count: backslashCount))
          quoted.append(String(unquoted[firstNonBackslash]))
        }
        unquoted.removeFirst(backslashCount + 1)
      }
      quoted.append("\"")
      return quoted
    }.joined(separator: " ")
}
#endif
#endif
