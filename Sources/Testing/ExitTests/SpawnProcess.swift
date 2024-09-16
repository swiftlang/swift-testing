//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

#if !SWT_NO_EXIT_TESTS
/// Spawn a process and wait for it to terminate.
///
/// - Parameters:
///   - executablePath: The path to the executable to spawn.
///   - arguments: The arguments to pass to the executable, not including the
///     executable path.
///   - environment: The environment block to pass to the executable.
///
/// - Returns: The exit condition of the spawned process.
///
/// - Throws: Any error that prevented the process from spawning or its exit
///   condition from being read.
func spawnAndWait(
  forExecutableAtPath executablePath: String,
  arguments: [String],
  environment: [String: String]
) async throws -> ExitCondition {
  // Darwin and Linux differ in their optionality for the posix_spawn types we
  // use, so use this typealias to paper over the differences.
#if SWT_TARGET_OS_APPLE
  typealias P<T> = T?
#elseif os(Linux) || os(FreeBSD)
  typealias P<T> = T
#endif

#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD)
  let pid = try withUnsafeTemporaryAllocation(of: P<posix_spawn_file_actions_t>.self, capacity: 1) { fileActions in
    guard 0 == posix_spawn_file_actions_init(fileActions.baseAddress!) else {
      throw CError(rawValue: swt_errno())
    }
    defer {
      _ = posix_spawn_file_actions_destroy(fileActions.baseAddress!)
    }

    // Do not forward standard I/O.
    _ = posix_spawn_file_actions_addopen(fileActions.baseAddress!, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
    _ = posix_spawn_file_actions_addopen(fileActions.baseAddress!, STDOUT_FILENO, "/dev/null", O_WRONLY, 0)
    _ = posix_spawn_file_actions_addopen(fileActions.baseAddress!, STDERR_FILENO, "/dev/null", O_WRONLY, 0)

    return try withUnsafeTemporaryAllocation(of: P<posix_spawnattr_t>.self, capacity: 1) { attrs in
      guard 0 == posix_spawnattr_init(attrs.baseAddress!) else {
        throw CError(rawValue: swt_errno())
      }
      defer {
        _ = posix_spawnattr_destroy(attrs.baseAddress!)
      }
#if SWT_TARGET_OS_APPLE
      // Close all other file descriptors open in the parent. Note that Linux
      // does not support this flag and, unlike Foundation.Process, we do not
      // attempt to emulate it.
      _ = posix_spawnattr_setflags(attrs.baseAddress!, CShort(POSIX_SPAWN_CLOEXEC_DEFAULT))
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

  return try await wait(for: pid)
#elseif os(Windows)
  // NOTE: Windows processes are responsible for handling their own
  // command-line escaping. This code is adapted from the code in
  // swift-corelibs-foundation (SEE: quoteWindowsCommandLine()) which was
  // itself adapted from the code published by Microsoft at
  // https://learn.microsoft.com/en-gb/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
  let commandLine = (CollectionOfOne(executablePath) + arguments).lazy
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
  let environ = environment.map { "\($0.key)=\($0.value)"}.joined(separator: "\0") + "\0\0"

  let processHandle: HANDLE! = try commandLine.withCString(encodedAs: UTF16.self) { commandLine in
    try environ.withCString(encodedAs: UTF16.self) { environ in
      var processInfo = PROCESS_INFORMATION()

      var startupInfo = STARTUPINFOW()
      startupInfo.cb = DWORD(MemoryLayout.size(ofValue: startupInfo))
      guard CreateProcessW(
        nil,
        .init(mutating: commandLine),
        nil,
        nil,
        false,
        DWORD(CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT),
        .init(mutating: environ),
        nil,
        &startupInfo,
        &processInfo
      ) else {
        throw Win32Error(rawValue: GetLastError())
      }
      _ = CloseHandle(processInfo.hThread)

      return processInfo.hProcess
    }
  }
  defer {
    CloseHandle(processHandle)
  }

  return try await wait(for: processHandle)
#else
#warning("Platform-specific implementation missing: process spawning unavailable")
  throw SystemError(description: "Exit tests are unimplemented on this platform.")
#endif
}
#endif
