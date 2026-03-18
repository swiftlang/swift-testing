//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing

struct `Inherited test function tests` {
  open class BaseClass {
    var calledTestFunction = false

    @Test func `Invoke inherited test function`() {
      calledTestFunction = true
    }

    public required init() {}

    deinit {
      #expect(calledTestFunction)
    }

    class DoesNotInheritBaseClass {
      @Test func `This function should not be inherited`() {
        #expect(Self.self == DoesNotInheritBaseClass.self)
      }

      final class DoesNotInheritDerivedClass: DoesNotInheritBaseClass {}
    }
  }

  private class DerivedClass: BaseClass {}
  private final class TertiaryClass: DerivedClass {}
}
