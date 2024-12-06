//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing a Swift expression captured at compile-time from source
/// code.
///
/// Instances of this type are generally opaque to callers. They can be
/// converted to strings representing their source code (captured at compile
/// time) using `String.init(describing:)`.
///
/// If parsing is needed, use the swift-syntax package to convert an instance of
/// this type to an instance of `ExprSyntax` using a Swift expression such as:
///
/// ```swift
/// let swiftSyntaxExpr: ExprSyntax = "\(testExpr)"
/// ```
///
/// - Warning: This type is used to implement the `#expect(exitsWith:)`
///   macro. Do not use it directly. Tools can use the SPI ``Expression``
///   typealias if needed.
public struct __Expression: Sendable {
  /// An enumeration describing the various kinds of expression that can be
  /// captured.
  ///
  /// This type is not part of the public interface of the testing library.
  enum Kind: Sendable {
    /// The expression represents a single, complete syntax node.
    ///
    /// - Parameters:
    ///   - sourceCode: The source code of the represented expression.
    case generic(_ sourceCode: String)
  }

  /// The kind of syntax node represented by this instance.
  ///
  /// This property is not part of the public interface of the testing library.
  /// Use `String(describing:)` to access the source code represented by an
  /// instance of this type.
  var kind: Kind

  /// The source code of the original captured expression.
  @_spi(ForToolsIntegrationOnly)
  public var sourceCode: String {
    switch kind {
    case let .generic(sourceCode):
      return sourceCode
    }
  }

  /// A type which represents an evaluated value, which may include textual
  /// descriptions, type information, substructure, and other information.
  @_spi(ForToolsIntegrationOnly)
  public struct Value: Sendable {
    /// A description of this value, formatted using
    /// ``Swift/String/init(describingForTest:)``.
    public var description: String

    /// A debug description of this value, formatted using
    /// `String(reflecting:)`.
    public var debugDescription: String

    /// Information about the type of this value.
    public var typeInfo: TypeInfo

    /// The label associated with this value, if any.
    ///
    /// For non-child instances, or for child instances of members who do not
    /// have a label (such as elements of a collection), the value of this
    /// property is `nil`.
    public var label: String?

    /// Whether or not this value represents a collection of values.
    public var isCollection: Bool

    /// The children of this value, representing its substructure, if any.
    ///
    /// If the value this instance represents does not contain any substructural
    /// values but ``isCollection`` is `true`, the value of this property is an
    /// empty array. Otherwise, the value of this property is non-`nil` only if
    /// the value it represents contains substructural values.
    public var children: [Self]?

    /// Initialize an instance of this type describing the specified subject and
    /// its children (if any).
    ///
    /// - Parameters:
    ///   - subject: The subject this instance should describe.
    init(reflecting subject: Any) {
      var seenObjects: [ObjectIdentifier: AnyObject] = [:]
      self.init(_reflecting: subject, label: nil, seenObjects: &seenObjects)
    }

    /// Initialize an instance of this type describing the specified subject and
    /// its children (if any), recursively.
    ///
    /// - Parameters:
    ///   - subject: The subject this instance should describe.
    ///   - label: An optional label for this value. This should be a non-`nil`
    ///     value when creating instances of this type which describe
    ///     substructural values.
    ///   - seenObjects: The objects which have been seen so far while calling
    ///     this initializer recursively, keyed by their object identifiers.
    ///     This is used to halt further recursion if a previously-seen object
    ///     is encountered again.
    private init(
      _reflecting subject: Any,
      label: String?,
      seenObjects: inout [ObjectIdentifier: AnyObject]
    ) {
      let mirror = Mirror(reflecting: subject)

      // If the subject being reflected is an instance of a reference type (e.g.
      // a class), keep track of whether it has been seen previously. Later
      // logic uses this to avoid infinite recursion for values which have
      // cyclic object references.
      //
      // This behavior is gated on the display style of the subject's mirror
      // being `.class`. That could be incorrect if a subject implements a
      // custom mirror, but in that situation, the subject type is responsible
      // for avoiding data references.
      //
      // For efficiency, this logic matches previously-seen objects based on
      // their pointer using `ObjectIdentifier`. This requires conditionally
      // down-casting the subject to `AnyObject`, but Swift can downcast any
      // value to `AnyObject`, even value types. To ensure only true reference
      // types are tracked, this checks the metatype of the subject using
      // `type(of:)`, which is inexpensive. The object itself is stored as the
      // value in the dictionary to ensure it is retained for the duration of
      // the recursion.
      var objectIdentifierToRemove: ObjectIdentifier?
      var shouldIncludeChildren = true
      if mirror.displayStyle == .class, type(of: subject) is AnyObject.Type {
        let object = subject as AnyObject
        let objectIdentifier = ObjectIdentifier(object)
        let oldValue = seenObjects.updateValue(object, forKey: objectIdentifier)
        if oldValue != nil {
          shouldIncludeChildren = false
        } else {
          objectIdentifierToRemove = objectIdentifier
        }
      }
      defer {
        if let objectIdentifierToRemove {
          // Remove the object from the set of previously-seen objects after
          // (potentially) recursing to reflect children. This is so that
          // repeated references to the same object are still included multiple
          // times; only _cyclic_ object references should be avoided.
          seenObjects[objectIdentifierToRemove] = nil
        }
      }

      description = String(describingForTest: subject)
      debugDescription = String(reflecting: subject)
      typeInfo = TypeInfo(describingTypeOf: subject)
      self.label = label

      isCollection = switch mirror.displayStyle {
      case .some(.collection),
           .some(.dictionary),
           .some(.set):
        true
      default:
        false
      }

      if shouldIncludeChildren && (!mirror.children.isEmpty || isCollection) {
        self.children = mirror.children.map { child in
          Self(_reflecting: child.value, label: child.label, seenObjects: &seenObjects)
        }
      }
    }
  }

  /// A representation of the runtime value of this expression.
  ///
  /// If the runtime value of this expression has not been evaluated, the value
  /// of this property is `nil`.
  @_spi(ForToolsIntegrationOnly)
  public var runtimeValue: Value?

  /// Get an expanded description of this instance that contains the source
  /// code and runtime value (or values) it represents.
  ///
  /// - Returns: A string describing this instance.
  @_spi(ForToolsIntegrationOnly)
  public func expandedDescription() -> String {
    _expandedDescription(verbose: false)
  }

  /// Get an expanded description of this instance that contains the source
  /// code and runtime value (or values) it represents.
  ///
  /// - Returns: A string describing this instance.
  ///
  /// This function produces a more detailed description than
  /// ``expandedDescription()``, similar to how `String(reflecting:)` produces
  /// a more detailed description than `String(describing:)`.
  func expandedDebugDescription() -> String {
    _expandedDescription(verbose: true)
  }

  /// Get an expanded description of this instance that contains the source
  /// code and runtime value (or values) it represents.
  ///
  /// - Parameters:
  ///   - verbose: Whether or not to include more verbose output.
  ///
  /// - Returns: A string describing this instance.
  ///
  /// This function provides the implementation of ``expandedDescription()`` and
  /// ``expandedDebugDescription()``.
  private func _expandedDescription(verbose: Bool) -> String {
    var result = sourceCode

    if verbose, let qualifiedName = runtimeValue?.typeInfo.fullyQualifiedName {
      result = "\(result): \(qualifiedName)"
    }

    if let runtimeValue {
      let runtimeValueDescription = String(describingForTest: runtimeValue)
      // Hack: don't print string representations of function calls.
      if runtimeValueDescription != "(Function)" && runtimeValueDescription != result {
        result = "\(result) → \(runtimeValueDescription)"
      }
    } else {
      result = "\(result) → <not evaluated>"
    }

    return result
  }

  /// The set of parsed and captured subexpressions contained in this instance.
  @_spi(ForToolsIntegrationOnly)
  public internal(set) var subexpressions = [Self]()

  /// A description of the difference between the operands in this expression,
  /// if that difference could be determined.
  ///
  /// The value of this property is set for the binary operators `==` and `!=`
  /// when used to compare collections.
  ///
  /// If the containing expectation passed, the value of this property is `nil`
  /// because the difference is only computed when necessary to assist with
  /// diagnosing test failures.
  @_spi(Experimental) @_spi(ForToolsIntegrationOnly)
  public internal(set) var differenceDescription: String?

  @_spi(ForToolsIntegrationOnly)
  @available(*, deprecated, message: "The value of this property is always nil.")
  public var stringLiteralValue: String? {
    nil
  }
}

// MARK: - Codable

extension __Expression: Codable {}
extension __Expression.Kind: Codable {}
extension __Expression.Value: Codable {}

// MARK: - CustomStringConvertible, CustomDebugStringConvertible

extension __Expression: CustomStringConvertible, CustomDebugStringConvertible {
  /// Initialize an instance of this type containing the specified source code.
  ///
  /// - Parameters:
  ///   - sourceCode: The source code of the expression being described.
  ///
  /// To get the string value of an expression, pass it to
  /// `String.init(describing:)`.
  ///
  /// This initializer does not attempt to parse `sourceCode`.
  @_spi(ForToolsIntegrationOnly)
  public init(_ sourceCode: String) {
    self.init(kind: .generic(sourceCode))
  }

  public var description: String {
    sourceCode
  }

  public var debugDescription: String {
    String(reflecting: kind)
  }
}

extension __Expression.Value: CustomStringConvertible, CustomDebugStringConvertible {}

/// A type representing a Swift expression captured at compile-time from source
/// code.
///
/// Instances of this type are generally opaque to callers. They can be
/// converted to strings representing their source code (captured at compile
/// time) using `String.init(describing:)`.
///
/// If parsing is needed, use the swift-syntax package to convert an instance of
/// this type to an instance of `ExprSyntax` using a Swift expression such as:
///
/// ```swift
/// let swiftSyntaxExpr: ExprSyntax = "\(testExpr)"
/// ```
@_spi(ForToolsIntegrationOnly)
public typealias Expression = __Expression
