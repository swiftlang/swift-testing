//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Test: Identifiable {
  public struct ID: Sendable, Equatable, Hashable {
    /// The name of the module containing the corresponding test.
    public var moduleName: String

    /// The fully qualified name components (other than the module name) used to
    /// identify the corresponding test.
    public var nameComponents: [String]

    /// The source location of the corresponding test.
    ///
    /// The value of this property should be set to `nil` for instances of
    /// ``Test`` that represent test suite types.
    public var sourceLocation: SourceLocation?

    /// Initialize an instance of this type with the specified fully qualified
    /// name components.
    ///
    /// - Parameters:
    ///   - fullyQualifiedNameComponents: The fully qualified name components
    ///     for this ID.
    ///
    /// This initializer synthesizes values for the ``moduleName`` and
    /// ``nameComponents`` properties and sets the ``sourceLocation`` property
    /// to `nil`. It is used by the testing library's unit tests and by other
    /// initializers in this file.
    ///
    /// This initializer is not part of the public interface of the testing
    /// library.
    init(_ fullyQualifiedNameComponents: some Collection<String>) {
      moduleName = fullyQualifiedNameComponents.first ?? ""
      if fullyQualifiedNameComponents.count > 0 {
        nameComponents = Array(fullyQualifiedNameComponents.dropFirst())
      } else {
        nameComponents = []
      }
    }

    /// Initialize an instance of this type with the specified fully qualified
    /// name components.
    ///
    /// - Parameters:
    ///   - moduleName: The name of the module containing the corresponding test.
    ///   - nameComponents: The fully qualified name components (other than the
    ///     module name) of the corresponding test.
    ///   - sourceLocation: The source location of the corresponding test. For
    ///     test suite types, pass `nil`.
    @_spi(ExperimentalTestRunning)
    public init(moduleName: String, nameComponents: [String], sourceLocation: SourceLocation?) {
      self.moduleName = moduleName
      self.nameComponents = nameComponents
      self.sourceLocation = sourceLocation
    }

    /// Initialize an instance of this type representing the specified test
    /// suite type.
    ///
    /// - Parameters:
    ///   - type: The test suite type.
    ///
    /// This initializer produces a test ID corresponding to the given type.
    @_spi(ExperimentalTestRunning)
    public init(type: Any.Type) {
      self.init(Testing.nameComponents(of: type))
    }

    /// A representation of this instance suitable for use as a key path in a
    /// `Graph<String, ?>`.
    var keyPathRepresentation: [String] {
      var result = [String]()

      result.append(moduleName)
      result.append(contentsOf: nameComponents)
      if let sourceLocation {
        result.append(String(describing: sourceLocation))
      }

      return result
    }

    /// The ID of the parent test.
    ///
    /// If this test's ID has no parent (i.e. the test is at the root of a test
    /// graph), the value of this property is `nil`.
    public var parent: ID? {
      if sourceLocation != nil {
        return ID(moduleName: moduleName, nameComponents: nameComponents, sourceLocation: nil)
      }
      if nameComponents.isEmpty {
        return nil
      }
      return ID(moduleName: moduleName, nameComponents: nameComponents.dropLast(), sourceLocation: sourceLocation)
    }
  }

  public var id: ID {
    var result = containingType.map(ID.init)
      ?? ID(moduleName: sourceLocation.moduleName, nameComponents: [], sourceLocation: nil)

    if !isSuite {
      result.nameComponents.append(name)
      result.sourceLocation = sourceLocation
    }

    return result
  }
}

// MARK: - CustomStringConvertible

extension Test.ID: CustomStringConvertible {
  public var description: String {
    keyPathRepresentation.joined(separator: "/")
  }
}
