//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

@_spi(Experimental)
extension Test {
  /// A type describing values that can be attached to the output of a test run
  /// and inspected later by the user.
  ///
  /// Attachments are included in test reports in Xcode or written to disk when
  /// tests are run at the command line. To create an attachment, you need a
  /// value of some type that conforms to ``Test/Attachable``. Initialize an
  /// instance of ``Test/Attachment`` with that value and, optionally, a
  /// preferred filename to use when writing to disk.
  ///
  /// On Apple platforms, additional functionality is available if you import
  /// the [UniformTypeIdentifiers](https://developer.apple.com/documentation/uniformtypeidentifiers) module.
  public struct Attachment: Sendable {
    /// The value of this attachment.
    ///
    /// The type of this property's value may not match the type of the value
    /// originally used to create this attachment.
    public var attachableValue: any Attachable & Sendable /* & Copyable rdar://137614425 */

    /// The source location of the attachment.
    public var sourceLocation: SourceLocation

    /// The default preferred name to use if the developer does not supply one.
    package static var defaultPreferredName: String {
      "untitled"
    }

    /// The path to which the this attachment was written, if any.
    ///
    /// If a developer sets the ``Configuration/attachmentDirectoryPath``
    /// property of the current configuration before running tests, or if a
    /// developer passes `--experimental-attachment-path` on the command line,
    /// then attachments will be automatically written to disk when they are
    /// attached and the value of this property will describe the path where
    /// they were written.
    ///
    /// If no destination path is set, or if an error occurred while writing
    /// this attachment to disk, the value of this property is `nil`.
    @_spi(ForToolsIntegrationOnly)
    public var fileSystemPath: String?

    /// Initialize an instance of this type that encloses the given attachable
    /// value.
    ///
    /// - Parameters:
    ///   - attachableValue: The value that will be attached to the output of
    ///     the test run.
    ///   - preferredName: The preferred name of the attachment when writing it
    ///     to a test report or to disk. If `nil`, the testing library attempts
    ///     to derive a reasonable filename for the attached value.
    ///   - sourceLocation: The source location of the attachment.
    public init(
      _ attachableValue: some Attachable & Sendable & Copyable,
      named preferredName: String? = nil,
      sourceLocation: SourceLocation = #_sourceLocation
    ) {
      self.attachableValue = attachableValue
      self.preferredName = preferredName ?? Self.defaultPreferredName
      self.sourceLocation = sourceLocation
    }

    /// A filename to use when writing this attachment to a test report or to a
    /// file on disk.
    ///
    /// The value of this property is used as a hint to the testing library. The
    /// testing library may substitute a different filename as needed. If the
    /// value of this property has not been explicitly set, the testing library
    /// will attempt to generate its own value.
    public var preferredName: String
  }
}

// MARK: -

extension Test.Attachment {
  /// Attach this instance to the current test.
  ///
  /// An attachment can only be attached once.
  public consuming func attach() {
    Event.post(.valueAttached(self))
  }
}

// MARK: - Non-sendable and move-only attachments

/// A type that stands in for an attachable type that is not also sendable.
private struct _AttachableProxy: Test.Attachable, Sendable {
  /// The result of `withUnsafeBufferPointer(for:_:)` from the original
  /// attachable value.
  var encodedValue = [UInt8]()

  var estimatedAttachmentByteCount: Int?

  func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try encodedValue.withUnsafeBufferPointer(for: attachment, body)
  }
}

extension Test.Attachment {
  /// Initialize an instance of this type that encloses the given attachable
  /// value.
  ///
  /// - Parameters:
  ///   - attachableValue: The value that will be attached to the output of
  ///     the test run.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the testing library attempts
  ///     to derive a reasonable filename for the attached value.
  ///   - sourceLocation: The source location of the attachment.
  ///
  /// When attaching a value of a type that does not conform to both `Sendable`
  /// and `Copyable`, the testing library encodes it as data immediately. If the
  /// value cannot be encoded and an error is thrown, that error is recorded as
  /// an issue in the current test and the resulting instance of
  /// ``Test/Attachment`` is empty.
  @_disfavoredOverload
  public init(
    _ attachableValue: borrowing some Test.Attachable & ~Copyable,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    var proxyAttachable = _AttachableProxy()
    proxyAttachable.estimatedAttachmentByteCount = attachableValue.estimatedAttachmentByteCount

    // BUG: the borrow checker thinks that withErrorRecording() is consuming
    // attachableValue, so get around it with an additional do/catch clause.
    do {
      let proxyAttachment = Self(proxyAttachable, named: preferredName, sourceLocation: sourceLocation)
      proxyAttachable.encodedValue = try attachableValue.withUnsafeBufferPointer(for: proxyAttachment) { buffer in
        [UInt8](buffer)
      }
    } catch {
      Issue.withErrorRecording(at: sourceLocation) {
        // TODO: define new issue kind .valueAttachmentFailed(any Error)
        // (but only use it if the caught error isn't ExpectationFailedError,
        // SystemError, or APIMisuseError. We need a protocol for these things.)
        throw error
      }
    }

    self.init(proxyAttachable, named: preferredName, sourceLocation: sourceLocation)
  }
}

#if !SWT_NO_FILE_IO
// MARK: - Writing

extension Test.Attachment {
  /// Write the attachment's contents to a file in the specified directory.
  ///
  /// - Parameters:
  ///   - directoryPath: The directory that should contain the attachment when
  ///     written.
  ///
  /// - Throws: Any error preventing writing the attachment.
  ///
  /// - Returns: The path to the file that was written.
  ///
  /// The attachment is written to a file _within_ `directoryPath`, whose name
  /// is derived from the value of the ``Test/Attachment/preferredName``
  /// property.
  ///
  /// If you pass `--experimental-attachment-path` to `swift test`, the testing
  /// library automatically uses this function to persist attachments to the
  /// directory you specify.
  ///
  /// This function does not get or set the value of the attachment's
  /// ``fileSystemPath`` property. The caller is responsible for setting the
  /// value of this property if needed.
  ///
  /// This function is provided as a convenience to allow tools authors to write
  /// attachments to persistent storage the same way that Swift Package Manager
  /// does. You are not required to use this function.
  @_spi(ForToolsIntegrationOnly)
  public func write(toFileInDirectoryAtPath directoryPath: String) throws -> String {
    try write(
      toFileInDirectoryAtPath: directoryPath,
      appending: String(UInt64.random(in: 0 ..< .max), radix: 36)
    )
  }

  /// Write the attachment's contents to a file in the specified directory.
  ///
  /// - Parameters:
  ///   - directoryPath: The directory to which the attachment should be
  ///     written.
  ///   - usingPreferredName: Whether or not to use the attachment's preferred
  ///     name. If `false`, ``defaultPreferredName`` is used instead.
  ///   - suffix: A suffix to attach to the file name (instead of randomly
  ///     generating one.) This value may be evaluated multiple times.
  ///
  /// - Throws: Any error preventing writing the attachment.
  ///
  /// - Returns: The path to the file that was written.
  ///
  /// The attachment is written to a file _within_ `directoryPath`, whose name
  /// is derived from the value of the ``Test/Attachment/preferredName``
  /// property and the value of `suffix`.
  ///
  /// If the argument `suffix` always produces the same string, the result of
  /// this function is undefined.
  func write(toFileInDirectoryAtPath directoryPath: String, usingPreferredName: Bool = true, appending suffix: @autoclosure () -> String) throws -> String {
    let result: String

    let preferredName = usingPreferredName ? preferredName : Self.defaultPreferredName

    var file: FileHandle?
    do {
      // First, attempt to create the file with the exact preferred name. If a
      // file exists at this path (note "x" in the mode string), an error will
      // be thrown and we'll try again by adding a suffix.
      let preferredPath = appendPathComponent(preferredName, to: directoryPath)
      file = try FileHandle(atPath: preferredPath, mode: "wxb")
      result = preferredPath
    } catch {
      // Split the extension(s) off the preferred name. The first component in
      // the resulting array is our base name.
      var preferredNameComponents = preferredName.split(separator: ".")
      let firstPreferredNameComponent = preferredNameComponents[0]

      while true {
        preferredNameComponents[0] = "\(firstPreferredNameComponent)-\(suffix())"
        let preferredName = preferredNameComponents.joined(separator: ".")
        let preferredPath = appendPathComponent(preferredName, to: directoryPath)

        // Propagate any error *except* EEXIST, which would indicate that the
        // name was already in use (so we should try again with a new suffix.)
        do {
          file = try FileHandle(atPath: preferredPath, mode: "wxb")
          result = preferredPath
          break
        } catch let error as CError where error.rawValue == EEXIST {
          // Try again with a new suffix.
          continue
        } catch where usingPreferredName {
          // Try again with the default name before giving up.
          return try write(toFileInDirectoryAtPath: directoryPath, usingPreferredName: false, appending: suffix())
        }
      }
    }

    try attachableValue.withUnsafeBufferPointer(for: self) { buffer in
      try file!.write(buffer)
    }

    return result
  }
}

extension Configuration {
  /// Handle the given "value attached" event.
  ///
  /// - Parameters:
  ///   - event: The event to handle. This event must be of kind
  ///     ``Event/Kind/valueAttached(_:)``. If the associated attachment's
  ///     ``Test/Attachment/fileSystemPath`` property is not `nil`, this
  ///     function does nothing.
  ///   - context: The context associated with the event.
  ///
  /// This function is called automatically by ``handleEvent(_:in:)``. You do
  /// not need to call it elsewhere. It automatically persists the attachment
  /// associated with `event` and modifies `event` to include the path where the
  /// attachment was stored.
  func handleValueAttachedEvent(_ event: inout Event, in eventContext: borrowing Event.Context) {
    guard let attachmentDirectoryPath else {
      // If there is no path to which attachments should be written, there's
      // nothing to do.
      return
    }

    guard case let .valueAttached(attachment) = event.kind else {
      preconditionFailure("Passed the wrong kind of event to \(#function) (expected valueAttached, got \(event.kind)). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    }
    if attachment.fileSystemPath != nil {
      // Somebody already persisted this attachment. This isn't necessarily a
      // logic error in the testing library, but it probably means we shouldn't
      // persist it again.
      return
    }

    // Write the attachment. If an error occurs, record it as an issue in the
    // current test.
    Issue.withErrorRecording(at: attachment.sourceLocation, configuration: self) {
      var attachment = attachment
      attachment.fileSystemPath = try attachment.write(toFileInDirectoryAtPath: attachmentDirectoryPath)
      event.kind = .valueAttached(attachment)
    }
  }
}
#endif
