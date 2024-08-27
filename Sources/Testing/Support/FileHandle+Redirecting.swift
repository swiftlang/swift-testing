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
extension FileHandle {
  typealias LineHandler = @Sendable (_ originalFileHandle: borrowing FileHandle, _ lineBuffer: UnsafeBufferPointer<CChar>) -> Void

  private final class _Cookie: Sendable {
    let originalFileHandle: FileHandle
    let lineHandler: LineHandler
    let buffer = Locked<[CChar]>(rawValue: [])

    init(originalFileHandle: consuming FileHandle, lineHandler: @escaping LineHandler) {
      self.originalFileHandle = originalFileHandle
      self.lineHandler = lineHandler
    }
  }

  static func replaceFile(_ originalFileHandle: consuming Self, with lineHandler: @escaping LineHandler) throws {
    let setFileHandle = originalFileHandle.withUnsafeCFILEHandle { originalFileHandle in
      if originalFileHandle == swt_stdout() {
        swt_stdout_set
      } else if originalFileHandle == swt_stderr() {
        swt_stderr_set
      } else {
        preconditionFailure("The specified file handle cannot be replaced at runtime. This is a bug blah blah")
      }
    }

    let cookie = _Cookie(originalFileHandle: originalFileHandle, lineHandler: lineHandler)
    let cookieAddress = Unmanaged.passRetained(cookie).toOpaque()

    let functions = cookie_io_functions_t(
      read: nil,
      write: { (cookie: UnsafeMutableRawPointer?, bytes: UnsafePointer<CChar>?, count: Int) -> Int in
        let cookie = Unmanaged<_Cookie>.fromOpaque(cookie!).takeUnretainedValue()
        cookie.buffer.withLock { buffer in
          buffer.append(contentsOf: UnsafeBufferPointer(start: bytes, count: count))

          let lastNewLineIndex = buffer.lastIndex { $0 == 10 || $0 == 13 }
          if let lastNewLineIndex {
            let lines: some Sequence<ArraySlice<CChar>> = buffer[...lastNewLineIndex].lazy
              .split(separator: [13, 10])
              .flatMap { $0.split { $0 == 10 || $0 == 13 } }
            for line in lines {
              line.withUnsafeBufferPointer { cookie.lineHandler(cookie.originalFileHandle, $0) }
            }
            buffer = Array(buffer[buffer.index(after: lastNewLineIndex)...])
          }
        }
        return count
      },
      seek: nil,
      close: { (cookie: UnsafeMutableRawPointer?) -> Int32 in
        let cookie = Unmanaged<_Cookie>.fromOpaque(cookie!).takeRetainedValue()
        cookie.buffer.withLock { buffer in
          // FIXME: drain whatever's left
        }
        return 0
      }
    )
    guard let fileHandle = fopencookie(cookieAddress, "wb", functions) else {
      throw CError(rawValue: swt_errno())
    }

    // Enable line buffering.
    _ = setvbuf(fileHandle, nil, _IOLBF, Int(BUFSIZ))

    setFileHandle(fileHandle)
  }
}
#endif
