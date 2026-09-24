// Implementations of the `__atomic_*` functions.

#if hasFeature(Embedded)

import EmbeddedPlatformGBACShims_Testing

@inline(__always)
private func withInterruptsDisabled<R>(_ body: () -> R) -> R {
  let ime = gba_disable_interrupts()
  let result = body()
  gba_restore_interrupts(ime)
  return result
}

@inline(__always)
private func load<T: FixedWidthInteger>(
  _ pointer: UnsafeRawPointer,
  as type: T.Type
) -> T {
  withInterruptsDisabled {
    pointer.load(as: T.self)
  }
}

@inline(__always)
private func store<T: FixedWidthInteger>(
  _ pointer: UnsafeMutableRawPointer,
  _ value: T
) {
  withInterruptsDisabled {
    pointer.storeBytes(of: value, as: T.self)
  }
}

@inline(__always)
private func exchange<T: FixedWidthInteger>(
  _ pointer: UnsafeMutableRawPointer,
  _ value: T
) -> T {
  withInterruptsDisabled {
    let old = pointer.load(as: T.self)
    pointer.storeBytes(of: value, as: T.self)
    return old
  }
}

@inline(__always)
private func compareExchange<T: FixedWidthInteger>(
  _ pointer: UnsafeMutableRawPointer,
  _ expected: UnsafeMutableRawPointer,
  _ desired: T
) -> Bool {
  withInterruptsDisabled {
    let current = pointer.load(as: T.self)
    if current == expected.load(as: T.self) {
      pointer.storeBytes(of: desired, as: T.self)
      return true
    }
    expected.storeBytes(of: current, as: T.self)
    return false
  }
}

@inline(__always)
private func fetch<T: FixedWidthInteger>(
  _ pointer: UnsafeMutableRawPointer,
  _ value: T,
  _ operation: (T, T) -> T
) -> T {
  withInterruptsDisabled {
    let old = pointer.load(as: T.self)
    pointer.storeBytes(of: operation(old, value), as: T.self)
    return old
  }
}

// MARK: - 1 byte

@c(__atomic_load_1) func atomicLoad1(_ p: UnsafeRawPointer, _ order: CInt)
  -> UInt8
{ load(p, as: UInt8.self) }
@c(__atomic_store_1) func atomicStore1(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt8,
  _ order: CInt
) { store(p, v) }
@c(__atomic_exchange_1) func atomicExchange1(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt8,
  _ order: CInt
) -> UInt8 { exchange(p, v) }
@c(__atomic_compare_exchange_1) func atomicCompareExchange1(
  _ p: UnsafeMutableRawPointer,
  _ e: UnsafeMutableRawPointer,
  _ d: UInt8,
  _ success: CInt,
  _ failure: CInt
) -> Bool { compareExchange(p, e, d) }
@c(__atomic_fetch_add_1) func atomicFetchAdd1(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt8,
  _ order: CInt
) -> UInt8 { fetch(p, v, &+) }
@c(__atomic_fetch_sub_1) func atomicFetchSub1(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt8,
  _ order: CInt
) -> UInt8 { fetch(p, v, &-) }
@c(__atomic_fetch_and_1) func atomicFetchAnd1(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt8,
  _ order: CInt
) -> UInt8 { fetch(p, v, &) }
@c(__atomic_fetch_or_1) func atomicFetchOr1(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt8,
  _ order: CInt
) -> UInt8 { fetch(p, v, |) }
@c(__atomic_fetch_xor_1) func atomicFetchXor1(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt8,
  _ order: CInt
) -> UInt8 { fetch(p, v, ^) }

// MARK: - 2 bytes

@c(__atomic_load_2) func atomicLoad2(_ p: UnsafeRawPointer, _ order: CInt)
  -> UInt16
{ load(p, as: UInt16.self) }
@c(__atomic_store_2) func atomicStore2(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt16,
  _ order: CInt
) { store(p, v) }
@c(__atomic_exchange_2) func atomicExchange2(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt16,
  _ order: CInt
) -> UInt16 { exchange(p, v) }
@c(__atomic_compare_exchange_2) func atomicCompareExchange2(
  _ p: UnsafeMutableRawPointer,
  _ e: UnsafeMutableRawPointer,
  _ d: UInt16,
  _ success: CInt,
  _ failure: CInt
) -> Bool { compareExchange(p, e, d) }
@c(__atomic_fetch_add_2) func atomicFetchAdd2(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt16,
  _ order: CInt
) -> UInt16 { fetch(p, v, &+) }
@c(__atomic_fetch_sub_2) func atomicFetchSub2(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt16,
  _ order: CInt
) -> UInt16 { fetch(p, v, &-) }
@c(__atomic_fetch_and_2) func atomicFetchAnd2(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt16,
  _ order: CInt
) -> UInt16 { fetch(p, v, &) }
@c(__atomic_fetch_or_2) func atomicFetchOr2(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt16,
  _ order: CInt
) -> UInt16 { fetch(p, v, |) }
@c(__atomic_fetch_xor_2) func atomicFetchXor2(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt16,
  _ order: CInt
) -> UInt16 { fetch(p, v, ^) }

// MARK: - 4 bytes

@c(__atomic_load_4) func atomicLoad4(_ p: UnsafeRawPointer, _ order: CInt)
  -> UInt32
{ load(p, as: UInt32.self) }
@c(__atomic_store_4) func atomicStore4(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt32,
  _ order: CInt
) { store(p, v) }
@c(__atomic_exchange_4) func atomicExchange4(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt32,
  _ order: CInt
) -> UInt32 { exchange(p, v) }
@c(__atomic_compare_exchange_4) func atomicCompareExchange4(
  _ p: UnsafeMutableRawPointer,
  _ e: UnsafeMutableRawPointer,
  _ d: UInt32,
  _ success: CInt,
  _ failure: CInt
) -> Bool { compareExchange(p, e, d) }
@c(__atomic_fetch_add_4) func atomicFetchAdd4(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt32,
  _ order: CInt
) -> UInt32 { fetch(p, v, &+) }
@c(__atomic_fetch_sub_4) func atomicFetchSub4(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt32,
  _ order: CInt
) -> UInt32 { fetch(p, v, &-) }
@c(__atomic_fetch_and_4) func atomicFetchAnd4(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt32,
  _ order: CInt
) -> UInt32 { fetch(p, v, &) }
@c(__atomic_fetch_or_4) func atomicFetchOr4(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt32,
  _ order: CInt
) -> UInt32 { fetch(p, v, |) }
@c(__atomic_fetch_xor_4) func atomicFetchXor4(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt32,
  _ order: CInt
) -> UInt32 { fetch(p, v, ^) }

// MARK: - 8 bytes

@c(__atomic_load_8) func atomicLoad8(_ p: UnsafeRawPointer, _ order: CInt)
  -> UInt64
{ load(p, as: UInt64.self) }
@c(__atomic_store_8) func atomicStore8(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt64,
  _ order: CInt
) { store(p, v) }
@c(__atomic_exchange_8) func atomicExchange8(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt64,
  _ order: CInt
) -> UInt64 { exchange(p, v) }
@c(__atomic_compare_exchange_8) func atomicCompareExchange8(
  _ p: UnsafeMutableRawPointer,
  _ e: UnsafeMutableRawPointer,
  _ d: UInt64,
  _ success: CInt,
  _ failure: CInt
) -> Bool { compareExchange(p, e, d) }
@c(__atomic_fetch_add_8) func atomicFetchAdd8(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt64,
  _ order: CInt
) -> UInt64 { fetch(p, v, &+) }
@c(__atomic_fetch_sub_8) func atomicFetchSub8(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt64,
  _ order: CInt
) -> UInt64 { fetch(p, v, &-) }
@c(__atomic_fetch_and_8) func atomicFetchAnd8(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt64,
  _ order: CInt
) -> UInt64 { fetch(p, v, &) }
@c(__atomic_fetch_or_8) func atomicFetchOr8(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt64,
  _ order: CInt
) -> UInt64 { fetch(p, v, |) }
@c(__atomic_fetch_xor_8) func atomicFetchXor8(
  _ p: UnsafeMutableRawPointer,
  _ v: UInt64,
  _ order: CInt
) -> UInt64 { fetch(p, v, ^) }

// MARK: - Arbitrary sizes

@c(__atomic_load)
func atomicLoad(
  _ size: Int,
  _ source: UnsafeRawPointer,
  _ destination: UnsafeMutableRawPointer,
  _ order: CInt
) {
  withInterruptsDisabled {
    destination.copyMemory(from: source, byteCount: size)
  }
}

@c(__atomic_store)
func atomicStore(
  _ size: Int,
  _ destination: UnsafeMutableRawPointer,
  _ source: UnsafeRawPointer,
  _ order: CInt
) {
  withInterruptsDisabled {
    destination.copyMemory(from: source, byteCount: size)
  }
}

@c(__atomic_compare_exchange)
func atomicCompareExchange(
  _ size: Int,
  _ pointer: UnsafeMutableRawPointer,
  _ expected: UnsafeMutableRawPointer,
  _ desired: UnsafeRawPointer,
  _ success: CInt,
  _ failure: CInt
) -> Bool {
  withInterruptsDisabled {
    let current = UnsafeRawBufferPointer(start: pointer, count: size)
    if current.elementsEqual(
      UnsafeRawBufferPointer(start: expected, count: size)
    ) {
      pointer.copyMemory(from: desired, byteCount: size)
      return true
    }
    expected.copyMemory(from: pointer, byteCount: size)
    return false
  }
}
#endif
