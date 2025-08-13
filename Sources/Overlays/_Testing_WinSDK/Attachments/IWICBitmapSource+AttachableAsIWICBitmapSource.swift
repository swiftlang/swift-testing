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

/// A protocol that provides a subclass of `IWICBitmapSource` with its
/// conformance to `_AttachableByAddressAsIWICBitmapSource`.
///
/// - Note: Because COM class inheritance is not visible in Swift, we must
///   manually apply conformances to this protocol to each COM type that
///   inherits from `IWICBitmapSource`.
///
/// This protocol is not part of the public interface of the testing library. It
/// allows us to reuse code across all subclasses of `IWICBitmapSource`.
protocol AttachableByAddressAsSubclassOfIWICBitmapSource: _AttachableByAddressAsIWICBitmapSource {
  /// The type of this COM class' vtable pointer.
  associatedtype Vtbl

  /// This instance's vtable pointer.
  var lpVtbl: UnsafeMutablePointer<Vtbl>! { get }
}

extension AttachableByAddressAsSubclassOfIWICBitmapSource {
  public static func _copyAttachableIWICBitmapSource(
    from imageAddress: UnsafeMutablePointer<Self>,
    using factory: UnsafeMutablePointer<IWICImagingFactory>
  ) throws -> UnsafeMutablePointer<IWICBitmapSource> {
    imageAddress.pointee.lpVtbl.withMemoryRebound(to: IUnknownVtbl.self, capacity: 1) { lpVtbl in
      _ = lpVtbl.pointee.AddRef(imageAddress)
    }
    return try imageAddress.cast(to: IWICBitmapSource.self)
  }

  public static func _copyAttachableValue(at imageAddress: UnsafeMutablePointer<Self>) -> UnsafeMutablePointer<Self> {
    imageAddress.pointee.lpVtbl.withMemoryRebound(to: IUnknownVtbl.self, capacity: 1) { lpVtbl in
      _ = lpVtbl.pointee.AddRef(imageAddress)
      return imageAddress
    }
  }

  public static func _deinitializeAttachableValue(at imageAddress: UnsafeMutablePointer<Self>) {
    imageAddress.pointee.lpVtbl.withMemoryRebound(to: IUnknownVtbl.self, capacity: 1) { lpVtbl in
      _ = lpVtbl.pointee.Release(imageAddress)
    }
  }
}

// MARK: -

extension UnsafeMutablePointer where Pointee: AttachableByAddressAsSubclassOfIWICBitmapSource {
  /// Upcast this WIC bitmap to a WIC bitmap source (its parent type).
  ///
  /// - Returns: `self`, cast to the parent type via `QueryInterface()`. The
  ///   caller is responsible for releasing the resulting object.
  ///
  /// - Throws: Any error that occurs while calling `QueryInterface()`. In
  ///   practice, this function is not expected to throw an error as it should
  ///   always be possible to cast a valid instance of `IWICBitmap` to
  ///   `IWICBitmapSource`.
  ///
  /// - Important: This function consumes a reference to `self` even if the cast
  ///   fails.
  consuming func cast(to _: IWICBitmapSource.Type) throws -> UnsafeMutablePointer<IWICBitmapSource> {
    self.pointee.lpVtbl.withMemoryRebound(to: IUnknownVtbl.self, capacity: 1) { lpVtbl in
      defer {
        _ = lpVtbl.pointee.Release(self)
      }

      return try withUnsafePointer(to: IID_IWICBitmapSource) { IID_IWICBitmapSource in
        var bitmapSource: UnsafeMutableRawPointer?
        let rQuery = lpVtbl.pointee.QueryInterface(self, IID_IWICBitmapSource, &bitmapSource)
        guard rQuery == S_OK, let bitmapSource else {
          throw ImageAttachmentError.queryInterfaceFailed(IWICBitmapSource.self, rQuery)
        }
        return bitmapSource.assumingMemoryBound(to: IWICBitmapSource.self)
      }
    }
  }
}

// MARK: - Conformances

@_spi(Experimental)
extension IWICBitmapSource: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICBitmap: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICBitmapFlipRotator: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICBitmapFrameDecode: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICBitmapScaler: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}
#endif
