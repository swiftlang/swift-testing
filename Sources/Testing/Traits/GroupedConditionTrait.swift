//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//


public struct GroupedConditionTrait: TestTrait, SuiteTrait {
    internal let conditionTraits: [ConditionTrait]
    internal let operations: [Operation]

    /// Initializes a new `GroupedConditionTrait`.
    /// - Parameters:
    ///   - conditionTraits: An array of `ConditionTrait`s to group. Defaults to an empty array.
    ///   - operations: An array of `Operation`s to apply between the condition traits. Defaults to an empty array.
    public init(conditionTraits: [ConditionTrait] = [], operations: [Operation] = []) {
        self.conditionTraits = conditionTraits
        self.operations = operations
    }

    /// Prepares the trait for a test by evaluating the grouped conditions.
    /// - Parameter test: The `Test` for which to prepare.
    public func prepare(for test: Test) async throws {
        _ = try await evaluate()
    }

    /// Evaluates the grouped condition traits based on the specified operations.
    ///
    /// - Returns: `true` if the grouped conditions evaluate to true, `false` otherwise.
    /// - Throws: `SkipInfo` if a condition evaluates to skip and the overall result is false.
    @_spi(Experimental)
    public func evaluate() async throws -> Bool {
        switch conditionTraits.count {
        case 0:
            preconditionFailure("GroupedConditionTrait must have at least one condition trait.")
        case 1:
            return try await conditionTraits.first!.evaluate()
        default:
            return try await evaluateGroupedConditions()
        }
    }

    private func evaluateGroupedConditions() async throws -> Bool {
        var result: Bool?
        var skipInfo: SkipInfo?

        for (index, operation) in operations.enumerated() where index < conditionTraits.count - 1 {
            do {
                let isEnabled = try await operation.operate(
                    conditionTraits[index],
                    conditionTraits[index + 1],
                    includeSkipInfo: true
                )
                result = updateResult(currentResult: result, isEnabled: isEnabled, operation: operation)
            } catch let error as SkipInfo {
                result = updateResult(currentResult: result, isEnabled: false, operation: operation)
                skipInfo = error
            }
        }

        if let skipInfo = skipInfo, !result! {
            throw skipInfo
        }

        return result!
    }

    private func updateResult(currentResult: Bool?, isEnabled: Bool, operation: Operation) -> Bool {
        if let currentResult = currentResult {
            return operation == .and ? currentResult && isEnabled : currentResult || isEnabled
        } else {
            return isEnabled
        }
    }
}

extension GroupedConditionTrait {
    /// Represents the logical operation to apply between two condition traits.
  public enum Operation : Sendable {
        /// Logical AND operation.
        case and
        /// Logical OR operation.
        case or

        /// Applies the logical operation between two condition traits.
        /// - Parameters:
        ///   - lhs: The left-hand side `ConditionTrait`.
        ///   - rhs: The right-hand side `ConditionTrait`.
        ///   - includeSkipInfo: A Boolean value indicating whether to include `SkipInfo` in the evaluation. Defaults to `false`.
        /// - Returns: `true` if the operation results in true, `false` otherwise.
        /// - Throws: `SkipInfo` if the operation results in false and `includeSkipInfo` is true.
        @discardableResult
        func operate(_ lhs: ConditionTrait, _ rhs: ConditionTrait, includeSkipInfo: Bool = false) async throws -> Bool {
            let (leftResult, rightResult) = try await evaluate(lhs, rhs)

            let isEnabled: Bool
            let skipSide: (comments: [Comment]?, sourceLocation: SourceLocation)

            switch self {
            case .and:
                isEnabled = evaluateAnd(left: lhs, right: rhs, leftResult: leftResult, rightResult: rightResult)
                skipSide = !isEnabled && !rightResult ? (lhs.comments, lhs.sourceLocation) : (rhs.comments, rhs.sourceLocation)
            case .or:
                isEnabled = evaluateOr(left: lhs, right: rhs, leftResult: leftResult, rightResult: rightResult)
                skipSide = !isEnabled ? (lhs.comments, lhs.sourceLocation) : (rhs.comments, rhs.sourceLocation)
            }

            guard isEnabled || !includeSkipInfo else {
                throw SkipInfo(comment: skipSide.comments?.first, sourceContext: SourceContext(backtrace: nil, sourceLocation: skipSide.sourceLocation))
            }
            return isEnabled
        }

        private func evaluate(_ lhs: ConditionTrait, _ rhs: ConditionTrait) async throws -> (Bool, Bool) {
            async let leftEvaluation = lhs.evaluate()
            async let rightEvaluation = rhs.evaluate()
            return (try await leftEvaluation, try await rightEvaluation)
        }

        private func evaluateAnd(left: ConditionTrait, right: ConditionTrait, leftResult: Bool, rightResult: Bool) -> Bool {
            return left.isInverted && right.isInverted ? leftResult || rightResult : leftResult && rightResult
        }

        private func evaluateOr(left: ConditionTrait, right: ConditionTrait, leftResult: Bool, rightResult: Bool) -> Bool {
            return left.isInverted && right.isInverted ? leftResult && rightResult : leftResult || rightResult
        }
    }
}

extension Trait where Self == GroupedConditionTrait {
    private static func createGroupedTrait(lhs: Self, rhs: ConditionTrait, operation: GroupedConditionTrait.Operation) -> Self {
        Self(conditionTraits: lhs.conditionTraits + [rhs], operations: lhs.operations + [operation])
    }

    private static func createGroupedTrait(lhs: Self, rhs: Self, operation: GroupedConditionTrait.Operation) -> Self {
        Self(conditionTraits: lhs.conditionTraits + rhs.conditionTraits, operations: lhs.operations + [operation] + rhs.operations)
    }

    /// Creates a new `GroupedConditionTrait` by performing a logical AND with another `ConditionTrait`.
    /// - Parameters:
    ///   - lhs: The left-hand side `GroupedConditionTrait`.
    ///   - rhs: The right-hand side `ConditionTrait`.
    /// - Returns: A new `GroupedConditionTrait` representing the logical AND of the two.
    static func && (lhs: Self, rhs: ConditionTrait) -> Self {
        createGroupedTrait(lhs: lhs, rhs: rhs, operation: .and)
    }

    /// Creates a new `GroupedConditionTrait` by performing a logical AND with another `GroupedConditionTrait`.
    /// - Parameters:
    ///   - lhs: The left-hand side `GroupedConditionTrait`.
    ///   - rhs: The right-hand side `GroupedConditionTrait`.
    /// - Returns: A new `GroupedConditionTrait` representing the logical AND of the two.
    static func && (lhs: Self, rhs: Self) -> Self {
        createGroupedTrait(lhs: lhs, rhs: rhs, operation: .and)
    }

    /// Creates a new `GroupedConditionTrait` by performing a logical OR with another `ConditionTrait`.
    /// - Parameters:
    ///   - lhs: The left-hand side `GroupedConditionTrait`.
    ///   - rhs: The right-hand side `ConditionTrait`.
    /// - Returns: A new `GroupedConditionTrait` representing the logical OR of the two.
    static func || (lhs: Self, rhs: ConditionTrait) -> Self {
        createGroupedTrait(lhs: lhs, rhs: rhs, operation: .or)
    }

    /// Creates a new `GroupedConditionTrait` by performing a logical OR with another `GroupedConditionTrait`.
    /// - Parameters:
    ///   - lhs: The left-hand side `GroupedConditionTrait`.
    ///   - rhs: The right-hand side `GroupedConditionTrait`.
    /// - Returns: A new `GroupedConditionTrait` representing the logical OR of the two.
    static func || (lhs: Self, rhs: Self) -> Self {
        createGroupedTrait(lhs: lhs, rhs: rhs, operation: .or)
    }
}

