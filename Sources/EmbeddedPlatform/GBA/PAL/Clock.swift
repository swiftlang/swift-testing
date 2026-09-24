#if hasFeature(Embedded)

import EmbeddedPlatformGBACShims_Testing
import _Volatile
import libc
import tonc

/// A monotonic clock driven by hardware timers 2 and 3.
///
/// The timer values come from 4 16-bit mmapped registers (referred to as
/// timer 2 and 3). They form the low and high halves of a 32-bit counter.
public enum SystemClock: Sendable {
  /// The number of ticks per second.
  public static let ticksPerSecond: UInt32 = 16384

  private static var timer2Counter: VolatileMappedRegister<UInt16> {
    .init(unsafeBitPattern: 0x0400_0108)
  }
  private static var timer2Control: VolatileMappedRegister<UInt16> {
    .init(unsafeBitPattern: 0x0400_010A)
  }
  private static var timer3Counter: VolatileMappedRegister<UInt16> {
    .init(unsafeBitPattern: 0x0400_010C)
  }
  private static var timer3Control: VolatileMappedRegister<UInt16> {
    .init(unsafeBitPattern: 0x0400_010E)
  }

  private static let enable = UInt16(TM_ENABLE)
  private static let cascade = UInt16(TM_CASCADE)
  private static let prescale1024 = UInt16(TM_FREQ_1024)

  /// Start the clock, if it isn't already running.
  public static func start() {
    guard timer3Control.load() & enable == 0 else { return }
    timer2Control.store(0)
    timer3Control.store(0)
    timer2Counter.store(0)
    timer3Counter.store(0)
    timer3Control.store(enable | cascade)
    timer2Control.store(enable | prescale1024)
  }

  /// The number of ticks since the clock was started.
  public static var ticks: UInt32 {
    start()
    // Re-read the high half until it's stable, in case the low half overflowed
    // between the reads.
    while true {
      let high = timer3Counter.load()
      let low = timer2Counter.load()
      if timer3Counter.load() == high {
        return UInt32(high) << 16 | UInt32(low)
      }
    }
  }

  public static var now: (seconds: UInt32, nanoseconds: UInt32) {
    let ticks = ticks
    let fraction = UInt64(ticks % ticksPerSecond)
    return (
      ticks / ticksPerSecond,
      UInt32(fraction * 1_000_000_000 / UInt64(ticksPerSecond))
    )
  }
}

// MARK: - POSIX clock functions

@implementation @c
func clock_gettime(
  _ clockID: clockid_t,
  _ tp: UnsafeMutablePointer<timespec>!
) -> CInt {
  let now = SystemClock.now
  tp.pointee.tv_sec = .init(now.seconds)
  tp.pointee.tv_nsec = .init(now.nanoseconds)
  return 0
}

@implementation @c
func clock_getres(
  _ clockID: clockid_t,
  _ res: UnsafeMutablePointer<timespec>!
) -> CInt {
  if let res {
    res.pointee.tv_sec = 0
    res.pointee.tv_nsec = .init(1_000_000_000 / SystemClock.ticksPerSecond)
  }
  return 0
}

@implementation @c
func nanosleep(
  _ rqtp: UnsafePointer<timespec>!,
  _ rmtp: UnsafeMutablePointer<timespec>!
) -> CInt {
  let request = rqtp.pointee
  guard request.tv_nsec >= 0 && request.tv_nsec < 1_000_000_000 else {
    gba_set_errno(EINVAL)
    return -1
  }
  let duration =
    UInt64(request.tv_sec) * UInt64(SystemClock.ticksPerSecond)
    + UInt64(request.tv_nsec) * UInt64(SystemClock.ticksPerSecond)
    / 1_000_000_000
  let start = SystemClock.ticks
  while UInt64(SystemClock.ticks &- start) < duration {}
  if let rmtp {
    rmtp.pointee.tv_sec = 0
    rmtp.pointee.tv_nsec = 0
  }
  return 0
}

@c func getentropy(_ buffer: UnsafeMutableRawPointer, _ length: Int) -> CInt {
  // Let's just assume the buffer is full of whatever random garbage is in RAM.
  return 0
}

#endif
