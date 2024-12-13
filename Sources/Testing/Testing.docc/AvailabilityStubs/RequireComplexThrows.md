# ``require(_:sourceLocation:performing:throws:)``

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

@Metadata {
  @Available(Swift, introduced: 6.0, deprecated: 999.0)
  @Available(Xcode, introduced: 16.0, deprecated: 999.0)
}

@DeprecationSummary {
  Examine the result of ``require(throws:_:sourceLocation:performing:)-7n34r``
  or ``require(throws:_:sourceLocation:performing:)-4djuw`` instead:
  
  ```swift
  let error = try #require(throws: FoodTruckError.self) {
    ...
  }
  #expect(error.napkinCount == 0)
  ```
}
