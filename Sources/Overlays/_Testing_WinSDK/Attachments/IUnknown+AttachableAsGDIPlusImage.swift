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
extension IUnknown: _AttachableByAddressAsGDIPlusImage {
  public static func _copyAttachableGDIPlusImage(at imageAddress: UnsafeMutablePointer<Self>) throws -> OpaquePointer {
    guard let image = swt_GdiplusImageCreateFromIUnknown(imageAddress) else {
      throw GDIPlusError.queryInterfaceFailed(/*E_NOINTERFACE = */HRESULT(bitPattern: 0x80004002))
    }
    return OpaquePointer(image)
  }

  public static func _cleanUpAttachment(at imageAddress: UnsafeMutablePointer<Self>) {
    imageAddress.Release()
  }
}
#endif
