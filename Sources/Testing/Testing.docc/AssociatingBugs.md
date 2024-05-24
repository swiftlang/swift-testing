# Associating bugs with tests

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Associate bugs uncovered or verified by tests.

## Overview

Tests allow developers to prove that the code they write is working as expected.
If code isn't working correctly, bug trackers are often used to track the work
necessary to fix the underlying problem. It's often useful to associate
specific bugs with tests that reproduce them or verify they are fixed.

- Note: "Bugs" as described in this document may also be referred to as
  "issues." To avoid confusion with the ``Issue`` type in the testing library,
  this document consistently refers to them as "bugs."

## Associate a bug with a test

To associate a bug with a test, use one of these functions:
- ``Trait/bug(_:_:)``
- ``Trait/bug(_:id:_:)-10yf5``
- ``Trait/bug(_:id:_:)-3vtpl``

The first argument to these functions is a URL representing the bug in its
bug-tracking system:

```swift
@Test("Food truck engine works", .bug("https://www.example.com/issues/12345"))
func engineWorks() async {
  var foodTruck = FoodTruck()
  await foodTruck.engine.start()
  #expect(foodTruck.engine.isRunning)
}
```

You can also specify the bug's _unique identifier_ in its bug-tracking system in
addition to, or instead of, its URL:

```swift
@Test(
  "Food truck engine works",
  .bug(id: "12345"),
  .bug("https://www.example.com/issues/67890", id: 67890)
)
func engineWorks() async {
  var foodTruck = FoodTruck()
  await foodTruck.engine.start()
  #expect(foodTruck.engine.isRunning)
}
```

A bug's URL is passed as a string and must be parseable according to
[RFC&nbsp;3986](https://www.ietf.org/rfc/rfc3986.txt). A bug's unique identifier
can be passed as an integer or as a string. For more information on the formats
recognized by the testing library, see <doc:BugIdentifiers>.

## Add titles to associated bugs

A bug's unique identifier or URL may be insufficient to uniquely and clearly
identify a bug associated with a test. Bug trackers universally provide a
"title" field for bugs that is not visible to the testing library. To add a
bug's title to a test, include it after the bug's unique identifier or URL:

```swift
@Test(
  "Food truck has napkins",
  .bug(id: "12345", "Forgot to buy more napkins")
)
func hasNapkins() async {
  ...
}
```
