//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A namespace for ABI symbols.
@_spi(ForToolsIntegrationOnly)
public enum ABI: Sendable {}

// MARK: - ABI version abstraction

extension ABI {
  /// A protocol describing the types that represent different ABI versions.
  public protocol Version: Sendable {
    /// The numeric representation of this ABI version.
    static var versionNumber: VersionNumber { get }

    /// Whether or not experimental fields should be included when using this
    /// ABI version.
    ///
    /// By default, the value of this property is `true` if any of the following
    /// conditions are satisfied:
    ///
    /// - The version number is less than 6.3. This is to preserve compatibility
    ///   with existing clients before the inclusion of experimental fields
    ///   became opt-in starting in 6.3.
    /// - The version number is greater than or equal to 6.3 and the environment
    ///   variable flag `SWT_EXPERIMENTAL_EVENT_STREAM_FIELDS_ENABLED` is set to
    ///   a true value.
    /// - The version number is greater than or equal to that of
    ///   ``ABI/ExperimentalVersion``.
    ///
    /// Otherwise, the value of this property is `false` by default.
    static var includesExperimentalFields: Bool { get }
  }

  /// A protocol that extends the public ``ABI/Version`` protocol with
  /// internal-only requirements.
  protocol _Version: Version {
#if !SWT_NO_ABI_JSON_SCHEMA
    /// Create an event handler that encodes events as JSON and forwards them to
    /// an ABI-friendly event handler.
    ///
    /// - Parameters:
    ///   - encodeAsJSONLines: Whether or not to ensure JSON passed to
    ///     `eventHandler` is encoded as JSON Lines (i.e. that it does not
    ///     contain extra newlines.)
    ///   - eventHandler: The event handler to forward events to.
    ///
    /// - Returns: An event handler.
    ///
    /// The resulting event handler outputs data as JSON. For each event handled
    /// by the resulting event handler, a JSON object representing it and its
    /// associated context is created and is passed to `eventHandler`.
    static func eventHandler(
      encodeAsJSONLines: Bool,
      forwardingTo eventHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
    ) -> Event.Handler
#endif
  }

  /// The current supported ABI version (ignoring any experimental versions.)
  public typealias CurrentVersion = v6_5

  /// Get the type representing a given ABI version.
  ///
  /// - Parameters:
  ///   - versionNumber: The ABI version number for which a concrete type is
  ///     needed.
  ///
  /// - Returns: A type conforming to ``ABI/Version`` that represents the given
  ///   ABI version, or `nil` if no such type exists.
  public static func version(forVersionNumber versionNumber: VersionNumber) -> (any Version.Type)? {
    _version(forVersionNumber: versionNumber)
  }

  /// Get the type representing a given ABI version.
  ///
  /// - Parameters:
  ///   - versionNumber: The ABI version number for which a concrete type is
  ///     needed.
  ///   - swiftCompilerVersion: The version number of the Swift compiler. This
  ///     is used when `versionNumber` is greater than the highest known version
  ///     to determine whether a version type can be returned. The default value
  ///     is the version of the Swift compiler which was used to build the
  ///     testing library.
  ///
  /// - Returns: A type conforming to ``ABI/Version`` that represents the given
  ///   ABI version, or `nil` if no such type exists.
  static func _version(
    forVersionNumber versionNumber: VersionNumber,
    givenSwiftCompilerVersion swiftCompilerVersion: @autoclosure () -> VersionNumber = swiftCompilerVersion
  ) -> (any _Version.Type)? {
    if versionNumber >= ABI.ExperimentalVersion.versionNumber {
      // The experimental ABI version is higher than any real ABI version.
      return ABI.ExperimentalVersion.self
    }

    if versionNumber > ABI.CurrentVersion.versionNumber {
      // If the caller requested an ABI version higher than the current Swift
      // compiler version and it's not an ABI version we've explicitly defined,
      // then we assume we don't know what they're talking about and return nil.
      //
      // Note that it is possible for the Swift compiler version to be lower
      // than the highest defined ABI version (e.g. if you use a 6.2 toolchain
      // to build this package's release/6.3 branch with a 6.3 ABI defined.)
      //
      // Note also that building an old version of Swift Testing with a newer
      // compiler may produce incorrect results here. We don't generally support
      // that configuration though.
      if versionNumber > swiftCompilerVersion() {
        return nil
      }
    }

    return switch versionNumber {
    case ABI.v6_5.versionNumber...:
      ABI.v6_5.self
    case ABI.v6_4.versionNumber...:
      ABI.v6_4.self
    case ABI.v6_3.versionNumber...:
      ABI.v6_3.self
    case ABI.v0.versionNumber...:
      ABI.v0.self
#if !SWT_NO_SNAPSHOT_TYPES
    case ABI.Xcode16.versionNumber:
      // Legacy support for Xcode 16. Support for this undocumented version will
      // be removed in a future update. Do not use it.
      ABI.Xcode16.self
#endif
    default:
      nil
    }
  }
}

#if !SWT_NO_ABI_JSON_SCHEMA
// MARK: - Decoding record JSON

extension ABI {
  /// Decode an event from the given record JSON.
  ///
  /// - Parameters:
  ///   - recordJSON: The record JSON to decode.
  ///   - context: A context value that tracks decoded tests and events.
  ///
  /// - Returns: A tuple containing the decoded event and an associated event
  ///   context. The event context's ``Event/Context/test`` and
  ///   ``Event/Context/iteration`` properties are set if the encoded event has
  ///   its corresponding properties set. The caller is responsible for setting
  ///   any other properties of the context value that it needs. If `recordJSON`
  ///   was invalid or could not be decoded, this function returns `nil`.
  ///
  /// Records of kind `"test"` are decoded as events of kind `testDiscovered`.
  ///
  /// This function infers the ABI version to use from the contents of
  /// `recordJSON`.
  public static func decodeEvent(fromRecordJSON recordJSON: UnsafeRawBufferPointer, in context: inout ABI.Context) -> (event: Event, context: Event.Context)? {
    guard let versionNumber = try? VersionNumber(fromRecordJSON: recordJSON),
          let abi = _version(forVersionNumber: versionNumber) else {
      return nil
    }
    return abi.decodeEvent(fromRecordJSON: recordJSON, in: &context)
  }
}

extension ABI.Version {
  /// Decode an event from the given record JSON.
  ///
  /// - Parameters:
  ///   - recordJSON: The record JSON to decode.
  ///   - context: A context value that tracks decoded tests and events.
  ///
  /// - Returns: A tuple containing the decoded event and an associated event
  ///   context. The event context's ``Event/Context/test`` and
  ///   ``Event/Context/iteration`` properties are set if the encoded event has
  ///   its corresponding properties set. The caller is responsible for setting
  ///   any other properties of the context value that it needs. If `recordJSON`
  ///   was invalid or could not be decoded, this function returns `nil`.
  ///
  /// Records of kind `"test"` are decoded as events of kind `testDiscovered`.
  ///
  /// If `recordJSON` was encoded with an incompatible ABI version, this
  /// function returns `nil`.
  public static func decodeEvent(fromRecordJSON recordJSON: UnsafeRawBufferPointer, in context: inout ABI.Context) -> (event: Event, context: Event.Context)? {
    var result: (event: Event, context: Event.Context)?

    guard let record = try? JSON.decode(ABI.Record<Self>.self, from: recordJSON) else {
      return nil
    }

    switch record.kind {
    case let .test(encodedTest):
      guard let test = Test(decoding: encodedTest, in: &context) else {
        return nil
      }
      result = (
        Event(.testDiscovered, testID: test.id, testCaseID: nil),
        Event.Context(test: test, testCase: nil, iteration: nil, configuration: nil)
      )
    case let .event(encodedEvent):
      guard let event = Event(decoding: encodedEvent, in: &context) else {
        return nil
      }
      let test = encodedEvent.testID.flatMap(context.test(identifiedBy:))
      result = (
        event,
        Event.Context(test: test, testCase: nil, iteration: encodedEvent.iteration, configuration: nil)
      )
    }

    return result
  }
}
#endif

// MARK: - Experimental fields

/// The value of the environment variable flag which enables experimental event
/// stream fields, if any.
private let _shouldIncludeExperimentalFlags = Environment.flag(named: "SWT_EXPERIMENTAL_EVENT_STREAM_FIELDS_ENABLED")

extension ABI.Version {
  public static var includesExperimentalFields: Bool {
    switch versionNumber {
    case ABI.ExperimentalVersion.versionNumber...:
      true
    case ABI.v6_3.versionNumber...:
      _shouldIncludeExperimentalFlags == true
    default:
      // Maintain behavior for pre-6.3 versions.
      true
    }
  }

  static func addingExperimentalFields() -> any ABI.Version.Type {
    if includesExperimentalFields {
      return self
    }

    return ABI._bespokeVersions.withLock { bespokeVersions in
      if let result = bespokeVersions[versionNumber] {
        return result
      }
      let name = "\(ABI.self).v\(versionNumber.majorComponent)_\(versionNumber.minorComponent)_\(versionNumber.patchComponent)_Experimental"

      var storage = ABI._DynamicVersion.Storage(
        versionNumber: versionNumber,
        includesExperimentalFields: true
      )
      let newClass = objc_allocateClassPair(ABI._DynamicVersion.self, name, MemoryLayout.size(ofValue: storage)) as! ABI._DynamicVersion.Type
      let storageAddress = object_getIndexedIvars(newClass)!
      storageAddress.copyMemory(from: &storage, byteCount: MemoryLayout.size(ofValue: storage))
      objc_registerClassPair(newClass)

      bespokeVersions[versionNumber] = newClass
      return newClass
    }
  }
}

extension ABI {
  private class _DynamicVersion: @unchecked Sendable, ABI.Version, ABI._Version {
    struct Storage: Sendable {
      var versionNumber: VersionNumber
      var includesExperimentalFields: Bool
    }

    static var versionNumber: ABI.VersionNumber {
      let storage = object_getIndexedIvars(self)!.loadUnaligned(as: Storage.self)
      return storage.versionNumber
    }

    static var includesExperimentalFields: Bool {
      let storage = object_getIndexedIvars(self)!.loadUnaligned(as: Storage.self)
      return storage.includesExperimentalFields
    }
  }
}

// MARK: - Concrete ABI versions

extension ABI {
#if !SWT_NO_SNAPSHOT_TYPES
  /// A namespace and version type for Xcode&nbsp;16 compatibility.
  ///
  /// - Warning: This type will be removed in a future update.
  enum Xcode16: Sendable, Version, _Version {
    static var versionNumber: VersionNumber {
      VersionNumber(-1, 0)
    }
  }
#endif

  /// A namespace and type for ABI version 0 symbols.
  public enum v0: Sendable, Version, _Version {
    public static var versionNumber: VersionNumber {
      VersionNumber(0, 0)
    }
  }

  /// A namespace and type for ABI version 6.3 symbols.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.3)
  ///   @Available(Xcode, introduced: 26.4)
  /// }
  public enum v6_3: Sendable, Version, _Version {
    public static var versionNumber: VersionNumber {
      VersionNumber(6, 3)
    }
  }

  /// A namespace and type for ABI version 6.4 symbols.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.4)
  ///   @Available(Xcode, introduced: 27.0)
  /// }
  public enum v6_4: Sendable, Version, _Version {
    public static var versionNumber: VersionNumber {
      VersionNumber(6, 4)
    }
  }

  /// A namespace and type for ABI version 6.5 symbols.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public enum v6_5: Sendable, Version, _Version {
    public static var versionNumber: VersionNumber {
      VersionNumber(6, 5)
    }
  }

  /// A namespace and type representing the ABI version whose symbols are
  /// considered experimental.
  @_spi(Experimental)
  public enum ExperimentalVersion: Sendable, Version, _Version {
    public static var versionNumber: VersionNumber {
      VersionNumber(99, 0)
    }
  }

  private static let _bespokeVersions = Mutex<[VersionNumber: (any Version.Type)]>()
}

#if !SWT_NO_CODABLE
// MARK: -

/// The set of keys accepted by `_swift_testing_copyMetadataValue(_:_:)`.
private enum _MetadataKey: String, Sendable, CaseIterable {
  /// The minimum supported ABI version.
  case minimumSupportedABIVersion = "_minimumSupportedABIVersion"

  /// The maximum supported ABI version.
  case maximumSupportedABIVersion = "_maximumSupportedABIVersion"
}

/// An exported C function that allows querying information about the testing
/// library without running any tests.
///
/// - Parameters:
///   - key: The name of the value of interest. See the `_MetadataKey`
///     enumeration for a list of supported values.
///   - reserved: Reserved for future use. Pass `0`.
///
/// - Returns: A pointer to a UTF-8 C string containing the JSON representation
///   of the requested information, or `nil` if that information was not
///   available. The caller is responsible for freeing this memory with C's
///   `free()` function.
@c
@usableFromInline
func _swift_testing_copyMetadataValue(_ key: UnsafePointer<CChar>, _ reserved: UInt) -> UnsafeMutablePointer<CChar>? {
  func copyJSON(for value: some Encodable) -> UnsafeMutablePointer<CChar>? {
    try? JSON.withEncoding(of: value) { json in
      json.withMemoryRebound(to: CChar.self) { json in
        // The JSON produced by Foundation is not null-terminated, so to avoid
        // an intermediate copy we call `calloc()` instead of `strdup()`.
        let result = calloc(json.count + 1, MemoryLayout<CChar>.stride)
        guard let result = result?.assumingMemoryBound(to: CChar.self) else {
          return nil
        }
        result.initialize(from: json.baseAddress!, count: json.count)
        return result
      }
    }
  }

  switch String(validatingCString: key).flatMap(_MetadataKey.init) {
  case .minimumSupportedABIVersion:
    return copyJSON(for: ABI.v0.versionNumber)
  case .maximumSupportedABIVersion:
    return copyJSON(for: ABI.CurrentVersion.versionNumber)
  case nil:
    return nil
  }
}
#endif
