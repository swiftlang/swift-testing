// Mutex stubs (GBA is single threaded so we just need to store "is locked".)

#if hasFeature(Embedded)

@c func _swift_mutex_init(_ mutex: UnsafeMutableRawPointer, _ flags: UInt) {
  mutex.storeBytes(of: 0, as: UInt.self)
}

@c func _swift_mutex_destroy(_ mutex: UnsafeMutableRawPointer) {}

@c func _swift_mutex_lock(_ mutex: UnsafeMutableRawPointer) {
  mutex.storeBytes(of: 1, as: UInt.self)
}

@c func _swift_mutex_unlock(_ mutex: UnsafeMutableRawPointer) {
  mutex.storeBytes(of: 0, as: UInt.self)
}

@c func _swift_mutex_tryLock(_ mutex: UnsafeMutableRawPointer) -> Int {
  if mutex.load(as: UInt.self) != 0 {
    return 0
  }
  mutex.storeBytes(of: 1, as: UInt.self)
  return 1
}

#endif
