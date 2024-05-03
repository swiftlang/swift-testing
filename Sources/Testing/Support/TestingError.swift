//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import TestingInternals

/// An enumeration representing an error in the testing library or its
/// underlying infrastructure.
///
/// When adding cases to this enumeration, consider if they will need to be
/// public or not. If test authors may need to specially handle them, they
/// probably don't belong here.
///
/// This type is not part of the public interface of the testing library.
/// External callers should generally record issues by throwing their own errors
/// or by calling ``Issue/record(_:fileID:filePath:line:column:)``.
enum TestingError: Error {
  /// An error from a C function such as `fopen()`.
  ///
  /// - Parameters:
  ///   - errorCode: The C error code, as from `errno`.
  ///
  /// This casetype is necessary because Foundation's `POSIXError` is not
  /// available in all contexts.
  case errno(_ errorCode: CInt)

#if os(Windows)
  /// A case representing a Windows error from a Win32 API function.
  ///
  /// - Parameters:
  ///   - errorCode: The Win32 error code, as from `GetLastError()`.
  ///
  /// Values of this case are in the domain described by Microsoft
  /// [here](https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes).
  case win32(_ errorCode: DWORD)
#endif

  /// An error in the testing library, its underlying infrastructure, or the
  /// operating system.
  ///
  /// - Parameters:
  ///   - explanation: A human-readable explanation of the error.
  case system(_ explanation: String)

  /// A feature is unavailable.
  ///
  /// - Parameters:
  ///   - explanation: An explanation of the problem.
  case featureUnavailable(_ explanation: String)

  /// An argument passed to the command-line interface was invalid.
  ///
  /// - Parameters:
  ///   - name: The name of the argument.
  ///   - value: The invalid value.
  case invalidArgument(_ name: String, value: String)
}

// MARK: -

/// Get a string describing a C error code.
///
/// - Parameters:
///   - errorCode: The error code to describe.
///
/// - Returns: A Swift string equal to the result of `strerror()` from the C
///   standard library.
func strerror(_ errorCode: CInt) -> String {
#if os(Windows)
  String(unsafeUninitializedCapacity: 1024) { buffer in
    _ = strerror_s(buffer.baseAddress!, buffer.count, errorCode)
    return strnlen(buffer.baseAddress!, buffer.count)
  }
#else
  String(cString: TestingInternals.strerror(errorCode))
#endif
}

#if os(Windows)
/// Get a string describing a Win32 error code.
///
/// - Parameters:
///   - errorCode: The error code to describe.
///
/// - Returns: A Swift string equal to the result of `FormatMessageW()` from the
///   Windows API.
func description(ofWin32ErrorCode errorCode: DWORD) -> String {
  let (address, count) = withUnsafeTemporaryAllocation(of: LPWSTR?.self, capacity: 1) { buffer in
    // FormatMessageW() takes a wide-character buffer into which it writes the
    // error message... _unless_ you pass `FORMAT_MESSAGE_ALLOCATE_BUFFER` in
    // which case it takes a pointer-to-pointer that it populates with a
    // heap-allocated string. However, the signature for FormatMessageW() still
    // takes an LPWSTR? (Optional<UnsafeMutablePointer<wchar_t>>), so we need to
    // temporarily mis-cast the pointer before we can pass it in.
    let count = buffer.withMemoryRebound(to: wchar_t.self) { buffer in
      FormatMessageW(
        DWORD(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_MAX_WIDTH_MASK),
        nil,
        errorCode,
        DWORD(swt_MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)),
        buffer.baseAddress,
        0,
        nil
      )
    }
    return (buffer.moveElement(from: buffer.startIndex), count)
  }
  defer {
    LocalFree(address)
  }
  if count > 0, let address, var result = String.decodeCString(address, as: UTF16.self)?.result {
    // Some of the strings produced by FormatMessageW() have trailing whitespace
    // we will want to remove.
    while let lastCharacter = result.last, lastCharacter.isWhitespace {
      result.removeLast()
    }
    return result
  }
  return "An unknown error occurred (\(errorCode))."
}
#endif

extension TestingError: CustomStringConvertible {
  var description: String {
    switch self {
    case let .errno(errorCode):
      strerror(errorCode)
#if os(Windows)
    case let .win32(errorCode):
      description(ofWin32ErrorCode: errorCode)
#endif
    case let .system(explanation), let .featureUnavailable(explanation):
      explanation
    case let .invalidArgument(name, value):
      #"Invalid value "\#(value)" for argument \#(name)"#
    }
  }
}
