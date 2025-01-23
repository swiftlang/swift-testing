# ``Trait``

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

## Topics

### Enabling and disabling tests

- ``Trait/enabled(if:_:sourceLocation:)``
- ``Trait/enabled(_:sourceLocation:_:)``
- ``Trait/disabled(_:sourceLocation:)``
- ``Trait/disabled(if:_:sourceLocation:)``
- ``Trait/disabled(_:sourceLocation:_:)``

### Controlling how tests are run

- ``Trait/timeLimit(_:)-4kzjp``
- ``Trait/serialized``
 
### Categorizing tests and adding information

- ``Trait/tags(_:)``
- ``Trait/comments``

### Associating bugs

- ``Trait/bug(_:_:)``
- ``Trait/bug(_:id:_:)-10yf5``
- ``Trait/bug(_:id:_:)-3vtpl``

### Run code before and after test functions

- ``TestScoping``
- ``Trait/scopeProvider(for:testCase:)-cjmg``
- ``Trait/TestScopeProvider``
- ``Trait/prepare(for:)-3s3zo``
