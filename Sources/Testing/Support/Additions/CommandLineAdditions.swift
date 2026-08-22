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

#if hasFeature(Embedded)
/// A minimal interface-compatible implementation of the `CommandLine` type from
/// the Swift standard library.
///
/// This type is declared for Embedded Swift targets to simplify calling code.
enum CommandLine {
  /// An array that provides access to this program's command line arguments.
  ///
  /// In Embedded Swift, this array contains one string standing in for the name
  /// of the current program (as required by the C language standard).
  static var arguments: [String] {
    ["swift-test"]
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
