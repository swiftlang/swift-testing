internal import WinSDK

/// A type describing the vtable of an `IUnknown` object.
/// 
/// For more information, see the definition of `IUnknownVtbl` in Microsoft's
/// `<unknwnbase.h>` header.
fileprivate typealias IUnknownVtbl = (
  /* QueryInterface (unused) */ @convention(c) () -> Void,
  AddRef: @convention(c) (
    UnsafeMutablePointer<IUnknown>
  ) -> ULONG,
  Release: @convention(c) (
    UnsafeMutablePointer<IUnknown>
  ) -> ULONG
)

extension UnsafeMutablePointer<IUnknown> {
  /// A pointer to the vtable of this `IUnknown` object.
  fileprivate var lpVtbl: UnsafePointer<IUnknownVtbl> {
    withMemoryRebound(to: UnsafePointer<IUnknownVtbl>.self, capacity: 1) { lpVtbl in
      lpVtbl.pointee
    }
  }

  /// Add a reference (retain) this `IUnknown` object.
  func AddRef() {
    _ = lpVtbl.pointee.AddRef(self)
  }

  /// Release this `IUnknown` object.
  func Release() {
    _ = lpVtbl.pointee.Release(self)
  }
}