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

To associate a bug with a test, use the ``Trait/bug(_:_:)-2u8j9`` or
``Trait/bug(_:_:)-7mo2w`` function. The first argument to this function is the
bug's _identifier_ in its bug-tracking system:

```swift
@Test("Food truck engine works", .bug("12345"), .bug(67890))
func engineWorks() async {
  var foodTruck = FoodTruck()
  await foodTruck.engine.start()
  #expect(foodTruck.engine.isRunning)
}
```

The bug identifier can be specified as an integer or as a string; if it is
specified as a string, it must be parseable as an unsigned integer or as a URL.
For more information on the formats recognized by the testing library, see
<doc:BugIdentifiers>.

## Add comments to associated bugs

A bug identifier may be insufficient to uniquely and clearly identify a bug
associated with a test. Bug trackers universally provide a "title" field for
bugs that is not visible to the testing library. To add a bug's title to a test,
include it after the bug's identifier:

```swift
@Test(
  "Food truck has napkins",
  .bug("12345", "Forgot to buy more napkins")
)
func hasNapkins() async {
  ...
}
```
