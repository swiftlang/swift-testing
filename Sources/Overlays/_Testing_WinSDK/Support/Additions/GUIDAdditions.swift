//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if compiler(<6.3) && os(Windows)
public import WinSDK

extension GUID: @retroactive Equatable, @retroactive Hashable {
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
