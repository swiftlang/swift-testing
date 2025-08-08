internal import WinSDK

/// A protocol describing COM types (that is, C++ classes that inherit from
/// `IUnknown`.
///
/// The testing library uses this protocol to simplify access to member
/// functions of COM types.
protocol IUnknownProtocol {
  /// The interface ID of this COM type.
  static var interfaceID: IID { get }

  /// The vtable type for this COM type.
  associatedtype Vtbl

  /// The address of this object's vtable structure.
  var lpVtbl: UnsafeMutablePointer<Vtbl>! { get }
}

extension UnsafeMutablePointer where Pointee: IUnknownProtocol {
  /// This object's vtable.
  ///
  /// This property is equivalent to `pointee.lpVtbl.pointee`.
  var lpVtbl: Pointee.Vtbl {
    unsafeAddress {
      .init(pointee.lpVtbl)
    }
  }

  /// Attempt to cast this object to an instance of another COM type.
  ///
  /// - Parameters:
  ///   - type: The COM type to cast `self` to.
  ///
  /// - Returns: `self`, cast to `type`. The caller is responsible for releasing
  ///   the resulting object. The bit pattern of the result may or may not equal
  ///   the bit pattern of `self`.
  ///
  /// - Throws: An `HSRESULT` value indicating why the cast failed.
  func QueryInterface<T>(_ type: T.Type) throws -> UnsafeMutablePointer<T> where T: IUnknownProtocol {
    try withMemoryRebound(to: IUnknown.self, capacity: 1) { `self` in
      try withUnsafePointer(to: T.interfaceID) { interfaceID in
        var result: UnsafeMutableRawPointer?
        let rQuery = self.lpVtbl.QueryInterface(self, interfaceID, &result)
        guard rQuery == S_OK, let result else {
          throw ImageAttachmentError.queryInterfaceFailed(type, rQuery)
        }
        return result.assumingMemoryBound(to: type)
      }
    }
  }

  /// Add a reference to this object (that is, retain it.)
  ///
  /// The caller is responsible for balancing calls to this function with calls
  /// to ``Release()``.
  func AddRef() {
    withMemoryRebound(to: IUnknown.self, capacity: 1) { `self` in
      _ = self.lpVtbl.AddRef(self)
    }
  }

  /// Release this object.
  func Release() {
    withMemoryRebound(to: IUnknown.self, capacity: 1) { `self` in
      _ = self.lpVtbl.Release(self)
    }
  }
}

// MARK: - Currency COM types

extension IUnknown: IUnknownProtocol {
  static var interfaceID: IID { IID_IUnknown }
}

extension IEnumUnknown: IUnknownProtocol {
  static var interfaceID: IID { IID_IEnumUnknown }
}

extension IPropertyBag2: IUnknownProtocol {
  static var interfaceID: IID { IID_IPropertyBag2 }
}

extension IStream: IUnknownProtocol {
  static var interfaceID: IID { IID_IStream }
}

// MARK: - WIC COM types

extension IWICBitmap: IUnknownProtocol {
  static var interfaceID: IID { IID_IWICBitmap }
}

extension IWICBitmapEncoder: IUnknownProtocol {
  static var interfaceID: IID { IID_IWICBitmapEncoder }
}

extension IWICBitmapEncoderInfo: IUnknownProtocol {
  static var interfaceID: IID { IID_IWICBitmapEncoderInfo }
}

extension IWICBitmapFrameEncode: IUnknownProtocol {
  static var interfaceID: IID { IID_IWICBitmapFrameEncode }
}

extension IWICBitmapSource: IUnknownProtocol {
  static var interfaceID: IID { IID_IWICBitmapSource }
}

extension IWICImagingFactory: IUnknownProtocol {
  static var interfaceID: IID { IID_IWICImagingFactory }
}