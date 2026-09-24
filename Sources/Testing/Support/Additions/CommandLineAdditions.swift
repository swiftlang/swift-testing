//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

#if canImport(Synchronization)
private import Synchronization
#endif

#if hasFeature(Embedded)
/// A minimal interface-compatible implementation of the `CommandLine` type from
/// the Swift standard library.
///
/// This type is declared for Embedded Swift targets to simplify calling code.
enum CommandLine {
  /// An array that provides access to this program's command line arguments.
  ///
  /// In Embedded Swift, the value of this property is initially set when
  /// `swift_testing_embeddedMain()` is called. If that function has not been
  /// called, the value of this property is a placeholder array containing a
  /// single string representing the program name.
  static var arguments: [String] {
    let argcArgv = _argcArgv.rawValue
    if argcArgv.argc > 0, let argv = argcArgv.argv {
      let result = (0 ..< Int(clamping: argcArgv.argc))
        .compactMap { String(validatingCString: argv[$0]) }
      if !result.isEmpty {
        return result
      }
    }
    return ["swift-test"]
  }
}
#endif

extension CommandLine {
#if !hasFeature(Embedded) && !os(WASI) && !SWT_TARGET_OS_APPLE
#if os(Windows)
  private typealias FPEncoding = UTF16
#else
  private typealias FPEncoding = UTF8
#endif

  private static var executablePathCString: ContiguousArray<FPEncoding.CodeUnit>? {
    @_silgen_name("_swift_stdlib_executablePathCString") get
  }
#endif

  /// The path to the current process' executable.
  static var executablePath: String {
    get throws {
#if hasFeature(Embedded) || os(WASI)
      // Embedded Swift and WASI do not currently support getting the executable
      // path via the standard library.
      throw SystemError(description: "The current executable path is not available on this platform.")
#elseif SWT_TARGET_OS_APPLE
      var result: String?
#if DEBUG
      var bufferCount = UInt32(1) // force looping
#else
      var bufferCount = UInt32(PATH_MAX)
#endif
      while result == nil {
        withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(bufferCount)) { buffer in
          // _NSGetExecutablePath returns 0 on success and -1 if bufferCount is
          // too small. If that occurs, we'll return nil here and loop with the
          // new value of bufferCount.
          if 0 == _NSGetExecutablePath(buffer.baseAddress, &bufferCount) {
            result = String(cString: buffer.baseAddress!)
          }
        }
      }
      return result!
#elseif os(Windows) && compiler(>=6.5)
      var result: String?
#if DEBUG
      var bufferCount = Int(1) // force looping
#else
      var bufferCount = Int(MAX_PATH)
#endif
      while result == nil {
        try withUnsafeTemporaryAllocation(of: CWideChar.self, capacity: bufferCount) { buffer in
          SetLastError(DWORD(ERROR_SUCCESS))
          _ = GetModuleFileNameW(nil, buffer.baseAddress!, DWORD(buffer.count))
          switch GetLastError() {
          case DWORD(ERROR_SUCCESS):
            result = String.decodeCString(buffer.baseAddress!, as: UTF16.self)?.result
            if result == nil {
              throw Win32Error(rawValue: DWORD(ERROR_ILLEGAL_CHARACTER))
            }
          case DWORD(ERROR_INSUFFICIENT_BUFFER):
            bufferCount += Int(MAX_PATH)
          case let errorCode:
            throw Win32Error(rawValue: errorCode)
          }
        }
      }
      return result!
#else
      guard let executablePathCString else {
#if os(Windows)
        throw Win32Error(rawValue: GetLastError())
#else
        throw CError(rawValue: swt_errno())
#endif
      }
      return try executablePathCString.withUnsafeBufferPointer { executablePathCString in
        guard let result = String.decodeCString(executablePathCString.baseAddress!, as: FPEncoding.self)?.result else {
          throw SystemError(description: "Could not decode the current executable's path as \(FPEncoding.self).")
        }
        return result
      }
#endif
    }
  }
}
