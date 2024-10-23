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

    /// An enumeration describing conditions under which at attachment should be
    /// written to disk.
    public enum WriteCondition: Sendable {
      /// The attachment should be written to disk as soon as it is attached to
      /// a test.
      case immediately

      /// The attachment should be written to disk after the test it is attached
      /// to finishes (regardless of whether it passes or fails.)
      case atEnd

      /// The attachment should be written to disk if the test it is attached to
      /// records an issue.
      ///
      /// Known issues recorded using ``withKnownIssue(_:isIntermittent:sourceLocation:_:)``
      /// are ignored for the purposes of writing an attachment to disk.
      case ifIssueRecorded

      /// The attachment should be written to disk if the test it is attached to
      /// does not record an issue.
      ///
      /// Known issues recorded using ``withKnownIssue(_:isIntermittent:sourceLocation:_:)``
      /// are ignored for the purposes of writing an attachment to disk.
      case unlessIssueRecorded
    }

    /// The conditions under which this attachment should be written to disk.
    public var writeCondition: WriteCondition

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
      writing writeCondition: WriteCondition = .immediately,
      sourceLocation: SourceLocation = #_sourceLocation
    ) {
      self.attachableValue = attachableValue
      self.preferredName = preferredName ?? Self.defaultPreferredName
      self.writeCondition = writeCondition
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
    writing writeCondition: WriteCondition = .immediately,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    var proxyAttachable = _AttachableProxy()

    // BUG: the borrow checker thinks that withErrorRecording() is consuming
    // attachableValue, so get around it with an additional do/catch clause.
    do {
      let proxyAttachment = Self(proxyAttachable, named: preferredName, writing: writeCondition, sourceLocation: sourceLocation)
      proxyAttachable.encodedValue = try attachableValue.withUnsafeBufferPointer(for: proxyAttachment) { buffer in
        [UInt8](buffer)
      }
    } catch {
      Issue.withErrorRecording(at: sourceLocation) {
        throw error
      }
    }

    self.init(proxyAttachable, named: preferredName, writing: writeCondition, sourceLocation: sourceLocation)
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
  func write(toFileInDirectoryAtPath directoryPath: String, appending suffix: @autoclosure () -> String) throws -> String {
    let result: String

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
        } catch let error as CError where error.rawValue == EEXIST {}
      }
    }

    try attachableValue.withUnsafeBufferPointer(for: self) { buffer in
      try file!.write(buffer)
    }

    return result
  }
}

extension Runner {
  /// Update this runner's configuration to write attachments to a directory
  /// when they are attached to tests.
  ///
  /// - Parameters:
  ///   - directoryPath: The directory to which attachments should be written.
  ///
  /// If an error occurs writing an attachment to disk, it is recorded as an
  /// issue in context of the current test.
  ///
  /// This event handler should be among the last ones composed so that event
  /// handlers provided by callers' (such as those in test harnesses or those
  /// that log output) will always see the attachment path.
  mutating func configureToWriteAttachments(toDirectoryAtPath directoryPath: String) {
    struct PerTestState: Sendable {
      var issueRecorded = false
      var pendingAttachments = [Test.Attachment]()
    }
    let state = Locked<[Test.ID: PerTestState]>()

    configuration.eventHandler = { [oldEventHandler = configuration.eventHandler] event, context in
      var attachmentsToWrite = [Test.Attachment]()

      switch event.kind {
      case let .valueAttached(attachment):
        // If the attachment is particularly large, write it immediately
        // regardless of its write condition.
        if attachment.attachableValue.underestimatedAttachableByteCount > (1 * 1024 * 1024) {
          attachmentsToWrite.append(attachment)
          break
        }

        let writeCondition = attachment.writeCondition
        switch writeCondition {
        case .immediately:
          attachmentsToWrite.append(attachment)
        case .atEnd:
          if let testID = event.testID {
            state.withLock { state in
              state[testID, default: .init()].pendingAttachments.append(attachment)
            }
          }
        case .ifIssueRecorded, .unlessIssueRecorded:
          if let testID = event.testID {
            state.withLock { state in
              var testState = state[testID, default: .init()]
              if testState.issueRecorded && writeCondition == .ifIssueRecorded {
                // Already recorded an issue. Write this attachment immediately.
                attachmentsToWrite.append(attachment)
              } else if !testState.issueRecorded && writeCondition == .unlessIssueRecorded {
                // Already recorded an issue. Do not store this attachment.
              } else {
                // Store this attachment for later (either on the next recorded
                // issue or when the test ends with no recorded issues.)
                testState.pendingAttachments.append(attachment)
                state[testID] = testState
              }
            }
          }
        }
      case let .issueRecorded(issue) where !issue.isKnown:
        // An issue was recorded. Write out any pending attachments that specify
        // .ifIssueRecorded and discard any that specify .unlessIssueRecorded.
        state.withLock { state in
          let testIDs = if let testID = event.testID {
            [testID]
          } else {
            // No test ID, so this is an orphaned issue. Since we don't know which
            // test to attribute this attachment to, we don't know if we should
            // write it or not. We'll treat all stored attachments as candidates.
            Array(state.keys)
          }

          for testID in testIDs {
            var testState = state[testID, default: .init()]
            defer {
              state[testID] = testState
            }

            // Drop any pending attachments that specify .unlessIssueRecorded.
            testState.pendingAttachments = testState.pendingAttachments
              .filter { $0.writeCondition != .unlessIssueRecorded }

            // Write out each attachment that specifies .ifIssueRecorded and
            // remove them from the pending attachment list.
            let partitionIndex = testState.pendingAttachments.partition { $0.writeCondition == .ifIssueRecorded }
            attachmentsToWrite += testState.pendingAttachments[partitionIndex...]
            testState.pendingAttachments = Array(testState.pendingAttachments[..<partitionIndex])
          }
        }
      case .testEnded:
        // All remaining pending attachments at this point should have specified
        // .atEnd or .unlessIssueRecorded.
        if let testID = event.testID {
          state.withLock { state in
            guard let testState = state.removeValue(forKey: testID) else {
              return
            }
            attachmentsToWrite += testState.pendingAttachments
#if DEBUG
            assert(testState.pendingAttachments.allSatisfy { $0.writeCondition == .atEnd || $0.writeCondition == .unlessIssueRecorded })
#endif
          }
        }
      default:
        // Not a relevant event.
        break
      }

      // Write all the attachments we gathered above.
      for attachment in attachmentsToWrite {
        _ = Issue.withErrorRecording(at: attachment.sourceLocation) {
          let path = try attachment.write(toFileInDirectoryAtPath: directoryPath)
          Event.post(.attachmentWritten(attachment, path: path), for: (context.test, context.testCase), configuration: context.configuration)
        }
      }

      oldEventHandler(event, context)
    }
  }
}
#endif
