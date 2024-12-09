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
  #expect(0 == strcmp("abc", "abc"))
  #expect(0 != strcmp("abc", "123"))
  #expect(swt_pointersNotEqual2("abc", "123"))
  #expect(swt_pointersNotEqual3("abc", "123", "def"))
  #expect(swt_pointersNotEqual4("abc", "123", "def", "456"))

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
