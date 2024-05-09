# Testing for errors in Swift code

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Ensure that your code handles errors in the way you expect.

## Overview

The Swift language provides an idiomatic approach to [error handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling), based on throwing errors where your code detects a failure for a caller to catch and react to.

Write tests for your code that validate the conditions in which the code throws errors, and the conditions in which it returns without throwing an error.
Use overrides of the `#expect()` and `#require()` macros that check for errors.

### Validate that your code throws an expected error

The Swift structure in this example represents a list that accepts any number of "tags" for items in the list.
The API contains a method for applying a tag to a range of items, and a method for retrieving the tags associated with the item at a given index.
Both of these methods throw errors if their parameters are outside the list's range.

```swift
struct TaggedArray<T> {
    enum TaggedArrayError : Error {
        case outOfRange
    }

    let elements: [T]
    var tags: [Int: [String]]

    init(list: [T]) {
        elements = list
        tags = [Int: [String]]()
    }

    mutating func add(tag: String, toObjectsIn range: Range<Int>) throws {
        guard Int(range.startIndex) >= 0 && Int(range.endIndex) < elements.count else {
            throw TaggedArrayError.outOfRange
        }
        for index in range {
            if var tagList = tags[index] {
                tagList.append(tag)
                tags[index] = tagList
            } else {
                tags[index] = [tag]
            }
        }
    }

    func tags(forItemAt index: Int) throws -> [String] {
        guard index >= 0 && index < elements.count else {
            throw TaggedArrayError.outOfRange
        }
        return tags[index] ?? []
    }

    // Other methods.
}
```

In your tests, validate that the code throws the error you expect by passing that error as the first argument of ``expect(throws:_:sourcelocation:performing:)-1xr34``, and pass a block that calls the code under test:

```swift
@Test func cannotAddTagToObjectBeforeStartOfList() {
    var array = TaggedArray(list: [1,2,3])
    #expect(throws: TaggedArray<Int>.TaggedArrayError.outOfRange) {
        try array.add(tag: "my tag", toObjectsIn: -1..<0)
    }
}
```

If the block completes without throwing an error, the testing library records an issue.
Other overloads of `#expect()` let you test that the code throws an error of a given type, or matching an arbitrary Boolean test.
Similar overloads of `#require()` stop running your test if the code doesn't throw the expected error.

### Validate that your code doesn't throw an error

Validate that the code under test doesn't throw an error by comparing the error to `Never`:

```swift
@Test func canAddTagToObjectInPositionZero() throws {
    var array = TaggedArray(list: [1,2,3])
    #expect(throws: Never.self) {
        try array.add(tag: "my tag", toObjectsIn: 0..<1)
    }
    #expect(try array.tags(forItemAt: 0) == ["my tag"])
}
```

If the block throws an error, the testing library records an issue.
If you need the test to stop if the code throws an error, include the code inline in the test function instead of wrapping it in an `#expect(throws:)` block.

> Note:
> `#require(throws:Never.self)` is deprecated, because calling the test code directly has the same effect as using the macro.
