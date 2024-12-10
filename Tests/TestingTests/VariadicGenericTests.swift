//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Testing
private import _TestingInternals

@Test func variadicCStringArguments() async throws {
  let abc = "abc"
  let _123 = "123"
  let def = "def"
  let _456 = "456"
  #expect(0 == strcmp(abc, abc))
  #expect(0 != strcmp(abc, _123))
  #expect(swt_pointersNotEqual2(abc, _123))
  #expect(swt_pointersNotEqual3(abc, _123, def))
  #expect(swt_pointersNotEqual4(abc, _123, def, _456))

  let nilString: String? = nil
  #expect(swt_nullableCString(nilString) == false)

  let lhs = "abc"
  let rhs = "123"
  #expect(0 != strcmp(lhs, rhs))
}

@Test func inoutAsPointerPassedToCFunction() {
  let num = CLong.random(in: 0 ..< 100)
  let str = String(describing: num)
  str.withCString { str in
    var endptr: UnsafeMutablePointer<CChar>?
    #expect(num == strtol(str, &endptr, 10))
    #expect(endptr != nil)
    #expect(endptr?.pointee == 0)
  }
}

@Test func utf16PointerConversions() throws {
  _ = try withUnsafeTemporaryAllocation(of: UTF16.CodeUnit.self, capacity: 1) { buffer in
    func f(_ p: UnsafeRawPointer?) -> Bool { true }
    func g(_ p: UnsafeMutableRawPointer?) -> Bool { true }
    func h(_ p: UnsafeMutablePointer<UTF16.CodeUnit>?) -> Bool { true }
    #expect(f(buffer.baseAddress))
    #expect(g(buffer.baseAddress))
    #expect(h(buffer.baseAddress))
    return try #require(String.decodeCString(buffer.baseAddress, as: UTF16.self)?.result)
  }
}
