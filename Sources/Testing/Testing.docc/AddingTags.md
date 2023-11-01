# Adding tags to tests

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Add tags to tests and customize their appearance.

## Overview

A complex package or project may contain hundreds or thousands of tests and
suites. Some subset of those tests may share some common facet, such as being
"critical" or "flaky". The testing library includes a type of trait called
"tags" that can be added to tests to group and categorize them.

Tags are different from test suites: test suites impose structure on test
functions at the source level, while tags provide semantic information for a
test that can be shared with any number of other tests across test suites,
source files, and even test targets.

## Adding tags

To add a tag to a test, use the ``Trait/tags(_:)-yg0i`` or
``Trait/tags(_:)-272p`` trait. These traits take sequences of tags as arguments,
and those tags are then applied to the corresponding test at runtime. If they
are applied to a test suite, then all tests in that suite inherit those tags.

Tags themselves are instances of ``Tag`` and can be expressed as string literals
or as named constants declared elsewhere:

```swift
extension Tag {
  static let legallyRequired = Tag(...)
}

@Test("Vendor's license is valid", .tags("critical", .legallyRequired))
func licenseValid() { ... }
```

The testing library does not assign any semantic meaning to any tags, nor does
the presence or absence of tags affect how the testing library runs tests.

## Topics

- ``Trait/tags(_:)-yg0i``
- ``Trait/tags(_:)-272p``
- ``Tag``
- ``Tag/List``
