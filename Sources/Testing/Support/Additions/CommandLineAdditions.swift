//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_FIXED_87344
private import _TestingInternals
#if canImport(Foundation)
private import Foundation
#endif

extension CommandLine {
  /// A temporary fallback implementation of the standard library's
  /// `CommandLine._executablePathCString` property.
#if !canImport(Foundation)
  @available(*, unavailable, message: "Requires Foundation or a newer Swift standard library")
#endif
  static let _executablePathCString: ContiguousArray? = {
#if canImport(Foundation)
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
#else
    swt_unreachable()
#endif
  }()
}
#endif
