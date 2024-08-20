# Known issues

<!--
This source file is part of the Swift.org open source project

Copyright © 2023–2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Highlight known issues when running tests.

## Overview

The testing library provides a function, `withKnownIssue()`, that you
use to mark issues as known. Use this function to inform the testing library 
at runtime not to mark the test as failing when issues occur.

## Topics

### Recording known issues in tests

- ``withKnownIssue(_:isIntermittent:sourceLocation:_:)``
- ``withKnownIssue(_:isIntermittent:isolation:sourceLocation:_:)``
- ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``
- ``withKnownIssue(_:isIntermittent:isolation:sourceLocation:_:when:matching:)``
- ``KnownIssueMatcher``

### Describing a failure or warning

- ``Issue``
