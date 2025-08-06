//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if os(Windows)
import Testing
import _Testing_WinSDK_GDIPlus

public import WinSDK

@_spi(Experimental)
extension HICON__: _AttachableByAddressAsGDIPlusImage {
  public static func _copyAttachableGDIPlusImage(at imageAddress: UnsafeMutablePointer<Self>) throws -> OpaquePointer {
    OpaquePointer(swt_GdiplusImageCreateFromHICON(imageAddress))
  }

  public static func _cleanUpAttachment(at imageAddress: UnsafeMutablePointer<Self>) {
    DeleteObject(imageAddress)
  }
}
#endif
