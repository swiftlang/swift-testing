//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if os(Windows) && compiler(<6.4)
public import WinSDK

// Retroactively add conformance to `Equatable` and `Hashable` until
// https://github.com/swiftlang/swift/pull/84792 is merged into the WinSDK Swift
// overlay.

@_spi(_)
extension GUID: @retroactive Equatable, @retroactive Hashable {
  /// This GUID as an integer.
  private var _uint128Value: UInt128 {
    withUnsafeBytes(of: self) { buffer in
      buffer.baseAddress!.loadUnaligned(as: UInt128.self)
    }
  }

  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs._uint128Value == rhs._uint128Value
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(_uint128Value)
  }
}
#endif
