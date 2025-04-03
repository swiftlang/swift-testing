//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// The contents of this file were copied more-or-less verbatim from
/// [swift-tools-support-core](https://github.com/swiftlang/swift-tools-support-core/blob/add9e1518ac37a8e52b7612d3eb2f009ae8f6ce8/Sources/TSCBasic/HashAlgorithms.swift).

/// SHA-256 implementation from Secure Hash Algorithm 2 (SHA-2) set of
/// cryptographic hash functions (FIPS PUB 180-2).
enum SHA256 {
  /// The length of the output digest (in bits).
  private static let _digestLength = 256

  /// The size of each blocks (in bits).
  private static let _blockBitSize = 512

  /// The initial hash value.
  private static let _initialHashValue: [UInt32] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  ]

  /// The constants in the algorithm (K).
  private static let _konstants: [UInt32] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ]

  public static func hash(_ bytes: some Sequence<UInt8>) -> [UInt8] {
    var input = Array(bytes)

    // Pad the input.
    _pad(&input)

    // Break the input into N 512-bit blocks.
    let messageBlocks = input.blocks(size: _blockBitSize / 8)

    /// The hash that is being computed.
    var hash = _initialHashValue

    // Process each block.
    for block in messageBlocks {
      _process(block, hash: &hash)
    }

    // Finally, compute the result.
    var result = [UInt8](repeating: 0, count: _digestLength / 8)
    for (idx, element) in hash.enumerated() {
      let pos = idx * 4
      result[pos + 0] = UInt8((element >> 24) & 0xff)
      result[pos + 1] = UInt8((element >> 16) & 0xff)
      result[pos + 2] = UInt8((element >> 8) & 0xff)
      result[pos + 3] = UInt8(element & 0xff)
    }

    return result
  }

  /// Process and compute hash from a block.
  private static func _process(_ block: ArraySlice<UInt8>, hash: inout [UInt32]) {

    // Compute message schedule.
    var W = [UInt32](repeating: 0, count: _konstants.count)
    for t in 0..<W.count {
      switch t {
      case 0...15:
        let index = block.startIndex.advanced(by: t * 4)
        // Put 4 bytes in each message.
        W[t]  = UInt32(block[index + 0]) << 24
        W[t] |= UInt32(block[index + 1]) << 16
        W[t] |= UInt32(block[index + 2]) << 8
        W[t] |= UInt32(block[index + 3])
      default:
        let σ1 = W[t-2].rotateRight(by: 17) ^ W[t-2].rotateRight(by: 19) ^ (W[t-2] >> 10)
        let σ0 = W[t-15].rotateRight(by: 7) ^ W[t-15].rotateRight(by: 18) ^ (W[t-15] >> 3)
        W[t] = σ1 &+ W[t-7] &+ σ0 &+ W[t-16]
      }
    }

    var a = hash[0]
    var b = hash[1]
    var c = hash[2]
    var d = hash[3]
    var e = hash[4]
    var f = hash[5]
    var g = hash[6]
    var h = hash[7]

    // Run the main algorithm.
    for t in 0..<_konstants.count {
      let Σ1 = e.rotateRight(by: 6) ^ e.rotateRight(by: 11) ^ e.rotateRight(by: 25)
      let ch = (e & f) ^ (~e & g)
      let t1 = h &+ Σ1 &+ ch &+ _konstants[t] &+ W[t]

      let Σ0 = a.rotateRight(by: 2) ^ a.rotateRight(by: 13) ^ a.rotateRight(by: 22)
      let maj = (a & b) ^ (a & c) ^ (b & c)
      let t2 = Σ0 &+ maj

      h = g
      g = f
      f = e
      e = d &+ t1
      d = c
      c = b
      b = a
      a = t1 &+ t2
    }

    hash[0] = a &+ hash[0]
    hash[1] = b &+ hash[1]
    hash[2] = c &+ hash[2]
    hash[3] = d &+ hash[3]
    hash[4] = e &+ hash[4]
    hash[5] = f &+ hash[5]
    hash[6] = g &+ hash[6]
    hash[7] = h &+ hash[7]
  }

  /// Pad the given byte array to be a multiple of 512 bits.
  private static func _pad(_ input: inout [UInt8]) {
    // Find the bit count of input.
    let inputBitLength = input.count * 8

    // Append the bit 1 at end of input.
    input.append(0x80)

    // Find the number of bits we need to append.
    //
    // inputBitLength + 1 + bitsToAppend ≡ 448 mod 512
    let mod = inputBitLength % 512
    let bitsToAppend = mod < 448 ? 448 - 1 - mod : 512 + 448 - mod - 1

    // We already appended first 7 bits with 0x80 above.
    input += [UInt8](repeating: 0, count: (bitsToAppend - 7) / 8)

    // We need to append 64 bits of input length.
    for byte in UInt64(inputBitLength).toByteArray().lazy.reversed() {
      input.append(byte)
    }
    assert((input.count * 8) % 512 == 0, "Expected padded length to be 512.")
  }
}

// MARK:- Helpers

extension UInt64 {
  /// Converts the 64 bit integer into an array of single byte integers.
  fileprivate func toByteArray() -> [UInt8] {
    var value = self.littleEndian
    return withUnsafeBytes(of: &value, Array.init)
  }
}

extension UInt32 {
  /// Rotates self by given amount.
  fileprivate func rotateRight(by amount: UInt32) -> UInt32 {
    return (self >> amount) | (self << (32 - amount))
  }
}

extension Array {
  /// Breaks the array into the given size.
  fileprivate func blocks(size: Int) -> AnyIterator<ArraySlice<Element>> {
    var currentIndex = startIndex
    return AnyIterator {
      if let nextIndex = self.index(currentIndex, offsetBy: size, limitedBy: self.endIndex) {
        defer { currentIndex = nextIndex }
        return self[currentIndex..<nextIndex]
      }
      return nil
    }
  }
}
