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

public import WinSDK

@_spi(Experimental)
extension IWICBitmap: _AttachableByAddressAsIWICBitmap {
  public static func _copyAttachableIWICBitmap(
    from imageAddress: UnsafeMutablePointer<Self>,
    using factory: UnsafeMutablePointer<IWICImagingFactory>
  ) throws -> UnsafeMutablePointer<IWICBitmap> {
    _ = imageAddress.AddRef()
    return imageAddress
  }

  public static func _deinitializeAttachment(at imageAddress: UnsafeMutablePointer<Self>) {
    _ = imageAddress.Release()
  }
}
#endif
