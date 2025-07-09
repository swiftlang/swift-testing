//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

//#if os(Windows)
//public import WinSDK
//private import _Testing_WinSDKInternals

public protocol AttachableAsGDIPlusImage {
  /// GDI+ objects are [not thread-safe](https://learn.microsoft.com/en-us/windows/win32/procthread/multiple-threads-and-gdi-objects)
  /// by design. The caller is responsible for guarding against concurrent
  /// access to the resulting GDI+ image object.
  func _withGDIPlusImage<R>(
    for attachment: Attachable<some AttachableWrapper<Self>>,
    _ body: (UnsafeMutableRawPointer) throws -> R
  ) throws -> R
}
//#endif
