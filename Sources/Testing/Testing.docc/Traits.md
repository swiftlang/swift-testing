# Adding traits to tests

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Add traits to tests to annotate them or customize their behavior.

## Overview

This article describes the ``Trait``, ``TestTrait``, and ``SuiteTrait``
protocols, lists the traits provided by the testing library, and lists functions
that can be used to create them.

The ``Trait``, ``TestTrait``, and ``SuiteTrait`` protocols are used to define
types that customize the behavior of test functions and test suites.

## Topics

### Defining conditions for a test

- <doc:EnablingAndDisabling>
- ``Trait/enabled(if:_:fileID:filePath:line:column:)``
- ``Trait/enabled(_:fileID:filePath:line:column:_:)``
- ``Trait/disabled(_:fileID:filePath:line:column:)``
- ``Trait/disabled(if:_:fileID:filePath:line:column:)``
- ``Trait/disabled(_:fileID:filePath:line:column:_:)``
- ``ConditionTrait``

### Adding tags to a test

- ``Trait/tags(_:)-yg0i``
- ``Trait/tags(_:)-272p``
- ``Tag``
- ``Tag/List``

### Adding a comment to a test

- <doc:AddingComments>
- ``Trait/comment(_:)``
- ``Comment``

### Referencing an issue or bug report from a test

- <doc:AssociatingBugs>
- <doc:BugIdentifiers>
- ``Trait/bug(_:relationship:)-duvt``
- ``Trait/bug(_:relationship:)-40riy``
- ``Bug``

### Limiting the execution time of a test

- ``TimeLimitTrait``
- ``Trait/timeLimit(_:)``

### Creating a custom trait

- ``Trait``
- ``TestTrait``
- ``SuiteTrait``
