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

    /// An ABI version equivalent to this one but set to represent development
    /// builds.
    associatedtype Dev: Version = _DevelopmentVersion<Self>

#if !SWT_NO_ABI_JSON_SCHEMA
    /// Create an event handler that encodes instances of ``Event`` as instances
    /// of ``ABI/Record`` and forwards them to a handler function.
    ///
    /// - Parameters:
    ///   - recordHandler: The record handler to forward events to.
    ///
    /// - Returns: An event handler.
    ///
    /// You can use this event handler with ``Configuration/eventHandler`` to
    /// automatically transform instances of ``Event`` to ``ABI/Record``.
    static func eventHandler(
      forwardingTo recordHandler: @escaping @Sendable (_ record: ABI.Record<Self>) -> Void
    ) -> Event.Handler

    /// Create an event handler that encodes events as JSON and forwards them to
    /// an ABI-friendly event handler.
    ///
    /// - Parameters:
    ///   - encodeAsJSONLines: Whether or not to ensure JSON passed to
    ///     `recordHandler` is encoded as JSON Lines (i.e. that it does not
    ///     contain extra newlines.)
    ///   - recordHandler: The event handler to forward events to.
    ///
    /// - Returns: An event handler.
    ///
    /// The resulting event handler outputs data as JSON. For each event handled
    /// by the resulting event handler, a JSON object representing it and its
    /// associated context is created and is passed to `recordHandler`.
    ///
    /// If `encodeAsJSONLines` is `true`, the resulting JSON does not include
    /// any newline characters (not even a trailing newline). If
    /// `encodeAsJSONLines` is `false`, it is unspecified whether the resulting
    /// JSON contains newline characters.
    ///
    /// You can use this event handler with ``Configuration/eventHandler`` to
    /// automatically transform instances of ``Event`` to JSON.
    static func eventHandler(
      encodeAsJSONLines: Bool,
      forwardingTo recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
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
    version(forVersionNumber: versionNumber, givenSwiftCompilerVersion: swiftCompilerVersion)
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
  static func version(
    forVersionNumber versionNumber: VersionNumber,
    givenSwiftCompilerVersion swiftCompilerVersion: @autoclosure () -> VersionNumber
  ) -> (any Version.Type)? {
    // If the caller needs a development version, check the logic for
    // non-development versions, then return the resulting version type's
    // equivalent development type.
    if versionNumber.flags.contains(.developmentBuild) {
      var versionNumberCopy = versionNumber
      versionNumberCopy.flags.remove(.developmentBuild)
      let result = version(forVersionNumber: versionNumberCopy, givenSwiftCompilerVersion: swiftCompilerVersion())
      func open<V>(_: V.Type) -> any Version.Type where V: Version {
        return V.Dev.self
      }
      return result.map { open($0) }
    }

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
    case ABI.Xcode16.Dev.versionNumber:
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
          let abi = version(forVersionNumber: versionNumber) else {
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
    case let .metadata(encodedMetadata):
      guard let metadata = Event.Metadata(decoding: encodedMetadata) else {
        return nil
      }
      result = (
        Event(.metadataRecorded(metadata), testID: nil, testCaseID: nil),
        Event.Context(test: nil, testCase: nil, iteration: nil, configuration: nil)
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
  /// Whether or not experimental fields should be included when using this
  /// ABI version.
  ///
  /// The value of this property is `true` if any of the following conditions
  /// are satisfied:
  ///
  /// - The version number is less than 6.3. This is to preserve compatibility
  ///   with existing clients before the inclusion of experimental fields became
  ///   opt-in starting in 6.3.
  /// - The version number is greater than or equal to 6.3 and the environment
  ///   variable flag `SWT_EXPERIMENTAL_EVENT_STREAM_FIELDS_ENABLED` is set to a
  ///   true value.
  /// - The version number is greater than or equal to that of ``ABI/ExperimentalVersion``.
  ///
  /// Otherwise, the value of this property is `false`.
  static var includesExperimentalFields: Bool {
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
}

// MARK: - Concrete ABI versions

extension ABI {
#if !SWT_NO_SNAPSHOT_TYPES
  /// A namespace and version type for Xcode&nbsp;16 compatibility.
  ///
  /// - Warning: This type will be removed in a future update.
  enum Xcode16: Sendable, Version {
    static var versionNumber: VersionNumber {
      VersionNumber(-1, 0)
    }
  }
#endif

  /// A namespace and type for ABI version 0 symbols.
  public enum v0: Sendable, Version {
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
  public enum v6_3: Sendable, Version {
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
  public enum v6_4: Sendable, Version {
    public static var versionNumber: VersionNumber {
      VersionNumber(6, 4)
    }
  }

  /// A namespace and type for ABI version 6.5 symbols.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.5)
  /// }
  public enum v6_5: Sendable, Version {
    public static var versionNumber: VersionNumber {
      VersionNumber(6, 5)
    }
  }

  /// A namespace and type representing the ABI version whose symbols are
  /// considered experimental.
  @_spi(Experimental)
  public enum ExperimentalVersion: Sendable, Version {
    public static var versionNumber: VersionNumber {
      VersionNumber(99, 0)
    }

    public typealias Dev = Self
  }
}

// MARK: - Development versions

extension ABI {
  public enum _DevelopmentVersion<V>: Sendable, Version where V: Version {
    public static var versionNumber: VersionNumber {
      var result = V.versionNumber
      result.flags.insert(.developmentBuild)
      return result
    }

    public typealias Dev = Self
  }
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
