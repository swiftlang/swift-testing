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
private import Foundation

extension CommandLine {
  static let _executablePathCString = {
    Bundle.main.executableURL
      .flatMap { $0.path(percentEncoded: false) }
      .map { path in
#if os(Windows)
        var result = ContiguousArray(path.utf16)
        result.append(0)
        return result
#else
        path.utf8CString
#endif
      }
  }()
}

// MARK: - Stringification

extension CommandLine {
  @available(swift, deprecated: 6.5, message: "Use '_executablePathCString' instead.")
  static var executablePath: String {
    get throws {
#if os(Windows)
      guard let _executablePathCString else {
        throw Win32Error(rawValue: GetLastError())
      }
      guard let result = String.decodeCString(buffer.baseAddress!, as: UTF16.self)?.result else {
        throw Win32Error(rawValue: DWORD(ERROR_ILLEGAL_CHARACTER))
      }
      return result
#elseif os(WASI)
      throw CError(rawValue: ENOTSUP)
#else
      guard let _executablePathCString else {
        throw CError(rawValue: swt_errno())
      }
      return try _executablePathCString.withUnsafeBufferPointer { path in
        guard let result = String(validatingCString: path.baseAddress!) else {
          throw CError(rawValue: EBADF)
        }
        return result
      }
#endif
    }
  }
}
