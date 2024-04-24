# Traits

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023–2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Add traits to tests to annotate them or customize their behavior.

## Overview

Pass built-in traits to test functions or suite types to comment, categorize, 
classify, and modify runtime behaviors. You can also use the ``Trait``, ``TestTrait``, 
and ``SuiteTrait`` protocols to create your own types that customize the 
behavior of test functions.

## Topics

### Customizing runtime behaviors

- <doc:EnablingAndDisabling>
- <doc:LimitingExecutionTime>
- <doc:Parallelization>
- ``Trait/enabled(if:_:fileID:filePath:line:column:)``
- ``Trait/enabled(_:fileID:filePath:line:column:_:)``
- ``Trait/disabled(_:fileID:filePath:line:column:)``
- ``Trait/disabled(if:_:fileID:filePath:line:column:)``
- ``Trait/disabled(_:fileID:filePath:line:column:_:)``
- ``Trait/timeLimit(_:)``

<!--
HIDDEN: .serial is experimental SPI pending feature review.
### Running tests serially or in parallel
- ``SerialTrait``
 -->

### Annotating tests

- <doc:AddingTags>
- <doc:AddingComments>
- <doc:AssociatingBugs>
- <doc:BugIdentifiers>
- ``Tag()``
- ``Trait/bug(_:relationship:_:)-86mmm``
- ``Trait/bug(_:relationship:_:)-3hsi5``

### Creating custom traits

- ``Trait``
- ``TestTrait``
- ``SuiteTrait``

### Supporting types

- ``Bug``
- ``Comment``
- ``ConditionTrait``
- ``Tag``
- ``Tag/List``
- ``TimeLimitTrait``
