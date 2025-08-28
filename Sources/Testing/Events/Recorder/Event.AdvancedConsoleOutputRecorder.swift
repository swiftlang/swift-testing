//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Event {
  /// An experimental console output recorder that provides enhanced test result
  /// display capabilities.
  ///
  /// This recorder is currently experimental and must be enabled via the
  /// `SWT_ENABLE_EXPERIMENTAL_CONSOLE_OUTPUT` environment variable.
  struct AdvancedConsoleOutputRecorder<V: ABI.Version>: Sendable {
    /// Configuration options for the advanced console output recorder.
    struct Options: Sendable {
      /// Base console output recorder options to inherit from.
      var base: Event.ConsoleOutputRecorder.Options
      
      init() {
        self.base = Event.ConsoleOutputRecorder.Options()
      }
    }
    
    /// Context for storing data across events during test execution.
    private struct _Context: Sendable {
      /// Storage for test information, keyed by test ID string value.
      /// This is needed because ABI.EncodedEvent doesn't contain full test context.
      var testStorage: [String: ABI.EncodedTest<V>] = [:]
      
      /// Hierarchical test tree structure using Graph for efficient operations.
      /// Key path represents the hierarchy (e.g., ["TestingTests", "ClockAPITests", "testMethod"])
      /// Value contains the test node data for that specific node.
      var testTree: Graph<String, _HierarchyNode?> = Graph()
      
      /// Consolidated test data for each test, keyed by test ID string.
      /// Contains all runtime information gathered during test execution.
      var testData: [String: _TestData] = [:]
      
      /// The instant when the test run was started.
      /// Used to calculate total run duration.
      var runStartTime: ABI.EncodedInstant<V>?
      
      /// The instant when the test run was completed.
      /// Used to calculate total run duration.
      var runEndTime: ABI.EncodedInstant<V>?
      
      /// The number of tests that passed during this run.
      var totalPassed: Int = 0
      
      /// The number of tests that failed during this run.
      var totalFailed: Int = 0
      
      /// The number of tests that were skipped during this run.
      var totalSkipped: Int = 0
    }
    
    /// Consolidated data for a single test, combining result, timing, and issues.
    private struct _TestData: Sendable {
      /// The final result of the test execution (passed, failed, or skipped).
      /// This is determined after all events for the test have been processed.
      var result: _TestResult?
      
      /// The instant when the test started executing.
      /// Used to calculate individual test duration.
      var startTime: ABI.EncodedInstant<V>?
      
      /// The instant when the test finished executing.
      /// Used to calculate individual test duration.
      var endTime: ABI.EncodedInstant<V>?
      
      /// All issues recorded during the test execution.
      /// Includes failures, warnings, and other diagnostic information.
      var issues: [ABI.EncodedIssue<V>] = []
    }
    
    /// Represents a node in the test hierarchy tree.
    /// Graph handles the parent-child relationships, so this only stores node-specific data.
    private struct _HierarchyNode: Sendable {
      /// The unique identifier for this test or test suite.
      let testID: String
      
      /// The base name of the test or suite without display formatting.
      let name: String
      
      /// The human-readable display name for the test or suite, if different from name.
      let displayName: String?
      
      /// Whether this node represents a test suite (true) or individual test (false).
      let isSuite: Bool
      
      init(testID: String, name: String, displayName: String?, isSuite: Bool) {
        self.testID = testID
        self.name = name
        self.displayName = displayName
        self.isSuite = isSuite
      }
    }
    
    /// Represents the result of a test execution.
    private enum _TestResult: Sendable {
      /// The test executed successfully without any failures.
      case passed
      
      /// The test failed due to one or more assertion failures or errors.
      case failed
      
      /// The test was skipped and did not execute.
      case skipped
    }
    
    /// The options for this recorder.
    let options: Options
    
    /// The write function for this recorder.
    let write: @Sendable (String) -> Void
    
    /// The fallback console recorder for standard output.
    private let _fallbackRecorder: Event.ConsoleOutputRecorder
    
    /// Context storage for test information and results.
    private let _context: Locked<_Context>
    
    /// Human-readable output recorder for generating messages.
    private let _humanReadableRecorder: Event.HumanReadableOutputRecorder
    
    /// Initialize the advanced console output recorder.
    ///
    /// - Parameters:
    ///   - options: Configuration options for the recorder.
    ///   - write: A closure that writes output to its destination.
    init(options: Options = Options(), writingUsing write: @escaping @Sendable (String) -> Void) {
      self.options = options
      self.write = write
      self._fallbackRecorder = Event.ConsoleOutputRecorder(options: options.base, writingUsing: write)
      self._context = Locked(rawValue: _Context())
      self._humanReadableRecorder = Event.HumanReadableOutputRecorder()
    }
  }
}

// MARK: - ASCII Fallback Support

extension Event.AdvancedConsoleOutputRecorder {
  /// Get the appropriate tree drawing character with ASCII fallback.
  ///
  /// - Parameters:
  ///   - unicode: The Unicode box-drawing character to use.
  ///   - ascii: The ASCII fallback character(s) to use.
  ///
  /// - Returns: The appropriate character based on terminal capabilities.
  private func _treeCharacter(unicode: String, ascii: String) -> String {
    // Use ASCII fallback on Windows or when ANSI escape codes are disabled
    // This follows the same pattern as Event.Symbol
#if os(Windows)
    return ascii
#else
    if options.base.useANSIEscapeCodes {
      return unicode
    } else {
      return ascii
    }
#endif
  }
  
  /// Get the tree branch character (├─).
  private var _treeBranch: String {
    _treeCharacter(unicode: "├─ ", ascii: "|- ")
  }
  
  /// Get the tree last branch character (╰─).
  private var _treeLastBranch: String {
    _treeCharacter(unicode: "╰─ ", ascii: "`- ")
  }
  
  /// Get the tree first branch character (┌─).
  private var _treeFirstBranch: String {
    _treeCharacter(unicode: "┌─ ", ascii: ".- ")
  }
  
  /// Get the tree vertical line character (│).
  private var _treeVertical: String {
    _treeCharacter(unicode: "│", ascii: "|")
  }
}

extension Event.AdvancedConsoleOutputRecorder {
  /// Record an event and its context.
  ///
  /// - Parameters:
  ///   - event: The event to record.
  ///   - eventContext: Contextual information about the event.
  public func record(_ event: borrowing Event, in eventContext: borrowing Event.Context) {
    // Extract values before entering lock to avoid borrowing issues
    let eventKind = event.kind
    let testValue = eventContext.test
    
    // Handle test discovery for hierarchy building
    if case .testDiscovered = eventKind, let test = testValue {
      let encodedTest = ABI.EncodedTest<V>(encoding: test)
      
      _context.withLock { context in
        _buildTestHierarchy(encodedTest, in: &context)
      }
    }
    
    // Convert Event to ABI.EncodedEvent for processing (if needed)
    let messages: [Event.HumanReadableOutputRecorder.Message] = []
    if let encodedEvent = ABI.EncodedEvent<V>(encoding: event, in: eventContext, messages: messages) {
      _processABIEvent(encodedEvent)
    }
    
    // Only output specific messages during the run, suppress most standard output
    // The hierarchical summary will be shown at the end
    switch eventKind {
    case .runStarted:
      let symbol = Event.Symbol.default.stringValue(options: _fallbackRecorder.options)
      write("\(symbol) Test run started.\n")
      
    case .runEnded:
      // The hierarchical summary is generated in _processABIEvent for runEnded
      break
      
    default:
      // Suppress other standard messages to avoid duplicate output
      // The hierarchy will show all the details at the end
      break
    }
  }
  
  /// Build the test hierarchy from discovered tests.
  ///
  /// - Parameters:
  ///   - encodedTest: The test to add to the hierarchy.
  ///   - context: The mutable context to update.
  private func _buildTestHierarchy(_ encodedTest: ABI.EncodedTest<V>, in context: inout _Context) {
    let testID = encodedTest.id.stringValue
    let isSuite = encodedTest.kind == .suite
    
    // Create hierarchy node
    let hierarchyNode = _HierarchyNode(
      testID: testID,
      name: encodedTest.name,
      displayName: encodedTest.displayName,
      isSuite: isSuite
    )
    
    // Parse the test ID to extract the key path for Graph
    let keyPath = _parseTestIDToKeyPath(testID)
    
    // Insert the node into the Graph at the appropriate key path
    context.testTree[keyPath] = hierarchyNode
    
    // Create intermediate nodes (modules and suites) if they don't exist
    for i in 1..<keyPath.count {
      let intermediateKeyPath = Array(keyPath.prefix(i))
      if context.testTree[intermediateKeyPath] == nil {
        // Create intermediate node
        let intermediateName = intermediateKeyPath.last ?? ""
        let intermediateNode = _HierarchyNode(
          testID: intermediateKeyPath.joined(separator: "."),
          name: intermediateName,
          displayName: intermediateName,
          isSuite: true
        )
        context.testTree[intermediateKeyPath] = intermediateNode
      }
    }

  }
  
  /// Parse a test ID into a key path suitable for Graph insertion.
  ///
  /// Examples:
  /// - "TestingTests.ClockAPITests/testMethod()" -> ["TestingTests", "ClockAPITests", "testMethod()"]
  /// - "TestingTests" -> ["TestingTests"]
  ///
  /// - Parameters:
  ///   - testID: The test ID to parse.
  /// - Returns: An array of key path components.
  private func _parseTestIDToKeyPath(_ testID: String) -> [String] {
    // Swift Testing test IDs include source location information
    // We need to extract the logical hierarchy path without source locations
    // Examples:
    // Suite: "TestingTests.HierarchyDemoTests/NestedSuite"
    // Test: "TestingTests.HierarchyDemoTests/failingTest()/HierarchyDemoTests.swift:21:4"
    
    let components = testID.split(separator: "/").map(String.init)
    var logicalPath: [String] = []
    
    for component in components {
      // Skip source location components (they contain .swift: pattern)
      if _containsSwiftFile(component) {
        break
      }
      logicalPath.append(component)
    }
    
    // Convert the first component from dot notation to separate components
    // e.g., "TestingTests.ClockAPITests" -> ["TestingTests", "ClockAPITests"]
    var keyPath: [String] = []
    
    if let firstComponent = logicalPath.first {
      let moduleParts = firstComponent.split(separator: ".").map(String.init)
      keyPath.append(contentsOf: moduleParts)
      
      // Add any additional path components (for nested suites)
      keyPath.append(contentsOf: logicalPath.dropFirst())
    }
    
    return keyPath.isEmpty ? [testID] : keyPath
  }
  
  /// Get all root nodes (module-level nodes) from the Graph.
  ///
  /// - Parameters:
  ///   - testTree: The Graph to extract root nodes from.
  /// - Returns: Array of key paths for root nodes (modules).
  private func _getRootNodes(from testTree: Graph<String, _HierarchyNode?>) -> [[String]] {
    var rootNodes: [[String]] = []
    var moduleNames: Set<String> = []
    
    // Find all unique module names (first component of key paths)
    testTree.forEach { keyPath, node in
      if node != nil && !keyPath.isEmpty {
        let moduleName = keyPath[0]
        moduleNames.insert(moduleName)
      }
    }
    
    // Convert module names to single-component key paths
    for moduleName in moduleNames.sorted() {
      rootNodes.append([moduleName])
    }
    
    return rootNodes
  }
  
  /// Get a hierarchy node from a test ID by searching the Graph.
  ///
  /// - Parameters:
  ///   - testID: The test ID to search for.
  ///   - testTree: The Graph to search in.
  /// - Returns: The hierarchy node if found.
  private func _getNodeFromTestID(_ testID: String, in testTree: Graph<String, _HierarchyNode?>) -> _HierarchyNode? {
    var foundNode: _HierarchyNode?
    
    testTree.forEach { keyPath, node in
      if node?.testID == testID {
        foundNode = node
      }
    }
    
    return foundNode
  }
  
  /// Get all child key paths for a given parent key path in the Graph.
  ///
  /// - Parameters:
  ///   - parentKeyPath: The parent key path.
  ///   - testTree: The Graph to search in.
  /// - Returns: Array of child key paths sorted alphabetically.
  private func _getChildKeyPaths(for parentKeyPath: [String], in testTree: Graph<String, _HierarchyNode?>) -> [[String]] {
    var childKeyPaths: [[String]] = []
    
    testTree.forEach { keyPath, node in
      if keyPath.count == parentKeyPath.count + 1 &&
         keyPath.prefix(parentKeyPath.count).elementsEqual(parentKeyPath) &&
         node != nil {
        childKeyPaths.append(keyPath)
      }
    }
    
    return childKeyPaths.sorted { $0.last ?? "" < $1.last ?? "" }
  }
  
  /// Find the key path for a given test ID in the Graph.
  ///
  /// - Parameters:
  ///   - testID: The test ID to search for.
  ///   - testTree: The Graph to search in.
  /// - Returns: The key path if found, nil otherwise.
  private func _findKeyPathForTestID(_ testID: String, in testTree: Graph<String, _HierarchyNode?>) -> [String]? {
    var foundKeyPath: [String]?
    
    testTree.forEach { keyPath, node in
      if node?.testID == testID {
        foundKeyPath = keyPath
      }
    }
    
    return foundKeyPath
  }
  
  /// Process an ABI.EncodedEvent for advanced console output.
  ///
  /// This implements the enhanced console logic for hierarchical display and failure summary.
  ///
  /// - Parameters:
  ///   - encodedEvent: The ABI-encoded event to process.
  private func _processABIEvent(_ encodedEvent: ABI.EncodedEvent<V>) {
    _context.withLock { context in
      switch encodedEvent.kind {
      case .runStarted:
        context.runStartTime = encodedEvent.instant
        
      case .testStarted:
        // Track test start time
        if let testID = encodedEvent.testID?.stringValue {
          var testData = context.testData[testID] ?? _TestData()
          testData.startTime = encodedEvent.instant
          context.testData[testID] = testData
        }
        
      case .issueRecorded:
        // Record issues for failure summary
        if let testID = encodedEvent.testID?.stringValue,
           let issue = encodedEvent.issue {
          var testData = context.testData[testID] ?? _TestData()
          testData.issues.append(issue)
          context.testData[testID] = testData
        }
        
      case .testEnded:
        // Track test end time and determine result
        if let testID = encodedEvent.testID?.stringValue {
          var testData = context.testData[testID] ?? _TestData()
          testData.endTime = encodedEvent.instant
          
          // Determine test result based on issues
          let hasFailures = testData.issues.contains { !$0.isKnown && ($0.isFailure ?? true) }
          let result: _TestResult = hasFailures ? .failed : .passed
          testData.result = result
          context.testData[testID] = testData
          
          // Update statistics
          switch result {
          case .passed:
            context.totalPassed += 1
          case .failed:
            context.totalFailed += 1
          case .skipped:
            context.totalSkipped += 1
          }
        }
        
      case .testSkipped:
        // Mark test as skipped
        if let testID = encodedEvent.testID?.stringValue {
          var testData = context.testData[testID] ?? _TestData()
          testData.result = .skipped
          context.testData[testID] = testData
          context.totalSkipped += 1
        }
        
      case .runEnded:
        context.runEndTime = encodedEvent.instant
        // Generate hierarchical summary
        _generateHierarchicalSummary(context: context)
        
      default:
        // Handle other event types
        break
      }
    }
  }
  
  /// Generate the final hierarchical summary when the run completes.
  ///
  /// - Parameters:
  ///   - context: The context containing all hierarchy and results data.
  private func _generateHierarchicalSummary(context: _Context) {
    var output = "\n"
    
    // Hierarchical Test Results
    output += "══════════════════════════════════════ HIERARCHICAL TEST RESULTS ══════════════════════════════════════\n"
    output += "\n"
    
    // Render the test hierarchy tree using Graph
    let rootNodes = _getRootNodes(from: context.testTree)
    
    if rootNodes.isEmpty {
      // Show test results as flat list if no hierarchy
      let allTests = context.testData.sorted { $0.key < $1.key }
      for (testID, testData) in allTests {
        let statusIcon = _getStatusIcon(for: testData.result ?? .passed)
        let testName = _getNodeFromTestID(testID, in: context.testTree)?.displayName ?? _getNodeFromTestID(testID, in: context.testTree)?.name ?? testID
        output += "\(statusIcon) \(testName)\n"
      }
    } else {
      // Render the test hierarchy tree
      for (index, rootKeyPath) in rootNodes.enumerated() {
        if let rootNode = context.testTree[rootKeyPath] {
          let isFirstRoot = index == 0
          let isLastRoot = index == rootNodes.count - 1
          let isSingleRoot = rootNodes.count == 1
          output += _renderHierarchyNode(rootNode, keyPath: rootKeyPath, context: context, prefix: "", isLast: isLastRoot, isFirstRoot: isFirstRoot, isSingleRoot: isSingleRoot)
          
          // Add spacing between top-level modules with vertical line continuation
          if index < rootNodes.count - 1 {
            output += "\(_treeVertical)\n"  // Add vertical line continuation between modules
          }
        }
      }
    }
    
    output += "\n"
    
    // Test run summary
    let totalTests = context.totalPassed + context.totalFailed + context.totalSkipped
    
    // Calculate total run duration
    var totalDuration = ""
    if let startTime = context.runStartTime, let endTime = context.runEndTime {
      totalDuration = _formatDuration(endTime.absolute - startTime.absolute)
    }
    
    // Format: [total] tests completed in [duration] ([pass symbol] pass: [number], [failed symbol] fail: [number], ...)
    let passIcon = _getStatusIcon(for: .passed)
    let failIcon = _getStatusIcon(for: .failed) 
    let skipIcon = _getStatusIcon(for: .skipped)
    
    var summaryParts: [String] = []
    if context.totalPassed > 0 {
      summaryParts.append("\(passIcon) pass: \(context.totalPassed)")
    }
    if context.totalFailed > 0 {
      summaryParts.append("\(failIcon) fail: \(context.totalFailed)")
    }
    if context.totalSkipped > 0 {
      summaryParts.append("\(skipIcon) skip: \(context.totalSkipped)")
    }
    
    let summaryDetails = summaryParts.joined(separator: ", ")
    let durationText = totalDuration.isEmpty ? "" : " in \(totalDuration)"
    output += "\(totalTests) test\(totalTests == 1 ? "" : "s") completed\(durationText) (\(summaryDetails))\n"
    output += "\n"
    
    // Failed Test Details (only if there are failures)
    let failedTests = context.testData.filter { $0.value.result == .failed }
    if !failedTests.isEmpty {
      output += "══════════════════════════════════════ FAILED TEST DETAILS ══════════════════════════════════════\n"
      output += "\n"
      
      // Iterate through all tests that recorded one or more failures
      for (testID, testData) in failedTests {
        // Get the fully qualified test name by traversing up the hierarchy
        let fullyQualifiedName = _getFullyQualifiedTestNameWithFile(testID: testID, context: context)
        
        let failureIcon = _getStatusIcon(for: .failed)
        output += "\(failureIcon) \(fullyQualifiedName)\n"
        
        // Show detailed issue information with proper indentation
        if !testData.issues.isEmpty {
          for issue in testData.issues {
            // Get detailed error description
            if let error = issue._error {
              let errorDescription = "\(error)"
              
              if !errorDescription.isEmpty && errorDescription != "Test failure" {
                output += "  Expectation failed:\n"
                
                // Split multi-line error descriptions and indent each line
                let errorLines = errorDescription.split(separator: "\n", omittingEmptySubsequences: false)
                for line in errorLines {
                  output += "    \(line)\n"
                }
              }
            }
            
            // Add source location
            if let sourceLocation = issue.sourceLocation {
              output += "  at \(sourceLocation.fileName):\(sourceLocation.line)\n"
            }
            
            output += "\n"
          }
        }
      }
    }
    
    write(output)
  }
  
  /// Render a hierarchy node with proper indentation and tree drawing characters.
  ///
  /// - Parameters:
  ///   - node: The node to render.
  ///   - context: The hierarchy context.
  ///   - prefix: The prefix for indentation and tree drawing.
  ///   - isLast: Whether this is the last child at its level.
  ///   - isFirstRoot: Whether this is the first root node.
  ///   - isSingleRoot: Whether there's only one root node in the entire hierarchy.
  /// - Returns: The rendered string for this node and its children.
  private func _renderHierarchyNode(_ node: _HierarchyNode, keyPath: [String], context: _Context, prefix: String, isLast: Bool, isFirstRoot: Bool, isSingleRoot: Bool = false) -> String {
    var output = ""
    
    if node.isSuite {
      // Suite header
      let treePrefix: String
      if prefix.isEmpty {
        if isSingleRoot {
          // Single root module: no tree prefix, flush left
          treePrefix = ""
        } else if isFirstRoot {
                  // Multiple roots: first root uses first branch character
        treePrefix = _treeFirstBranch
        } else {
          // Multiple roots: other roots use standard tree characters
          treePrefix = isLast ? _treeLastBranch : _treeBranch
        }
      } else {
        // Nested suites: use standard tree characters
        treePrefix = isLast ? _treeLastBranch : _treeBranch
      }
      
      let suiteName = node.displayName ?? node.name
      output += "\(prefix)\(treePrefix)\(suiteName)\n"
      
      // Render children with updated prefix  
      let childPrefix: String
      if prefix.isEmpty {
        if isSingleRoot {
          // Single root: children start with 3 spaces (no vertical line needed)
          childPrefix = "   "
        } else {
          // Multiple roots: children get 3 spaces as before
          childPrefix = "   "
        }
      } else {
        // Nested case: continue vertical line unless this is the last node
        childPrefix = prefix + (isLast ? "   " : "\(_treeVertical)  ")
      }
      
      let childKeyPaths = _getChildKeyPaths(for: keyPath, in: context.testTree)
      for (childIndex, childKeyPath) in childKeyPaths.enumerated() {
        let isLastChild = childIndex == childKeyPaths.count - 1
        if let childNode = context.testTree[childKeyPath] {
          output += _renderHierarchyNode(childNode, keyPath: childKeyPath, context: context, prefix: childPrefix, isLast: isLastChild, isFirstRoot: false, isSingleRoot: isSingleRoot)
          
          // Add spacing between child nodes when the next sibling is a suite
          // Continue the tree structure with vertical line
          if childIndex < childKeyPaths.count - 1 {
            // Check if the next sibling is a suite
            let nextChildKeyPath = childKeyPaths[childIndex + 1]
            if let nextChildNode = context.testTree[nextChildKeyPath], nextChildNode.isSuite {
              // Use the correct spacing prefix
              let spacingPrefix: String
              if prefix.isEmpty {
                if isSingleRoot {
                  // Single root case: use 3 spaces + vertical line
                  spacingPrefix = "   \(_treeVertical)"
                } else {
                  // Multiple roots case: use 3 spaces + vertical line
                  spacingPrefix = "   \(_treeVertical)"
                }
              } else {
                // Nested case: use the child prefix
                spacingPrefix = childPrefix
              }
              output += "\(spacingPrefix)\n"  // Add the vertical line continuation
            }
          }
        }
      }
    } else {
      // Test case line
      let treePrefix = isLast ? _treeLastBranch : _treeBranch
      let statusIcon = _getStatusIcon(for: context.testData[node.testID]?.result ?? .passed)
      let testName = node.displayName ?? node.name
      
      // Calculate duration
      var duration = ""
      if let startTime = context.testData[node.testID]?.startTime,
         let endTime = context.testData[node.testID]?.endTime {
        duration = _formatDuration(endTime.absolute - startTime.absolute)
      }
      
      // Format with right-aligned duration
      let testLine = "\(statusIcon) \(testName)"
      let paddedTestLine = _padWithDuration(testLine, duration: duration)
      output += "\(prefix)\(treePrefix)\(paddedTestLine)\n"
      
      // Render issues for failed tests
      if let issues = context.testData[node.testID]?.issues, !issues.isEmpty {
        let issuePrefix = prefix + (isLast ? "   " : "\(_treeVertical)  ")
        for (issueIndex, issue) in issues.enumerated() {
          let isLastIssue = issueIndex == issues.count - 1
          let issueTreePrefix = isLastIssue ? _treeLastBranch : _treeBranch
          let issueIcon = _getStatusIcon(for: .failed)
          let issueDescription = issue._error?.description ?? "Test failure"
          
          output += "\(issuePrefix)\(issueTreePrefix)\(issueIcon) \(issueDescription)\n"
          
          // Add source location
          if let sourceLocation = issue.sourceLocation {
            let locationPrefix = issuePrefix + (isLastIssue ? "   " : "\(_treeVertical)  ")
            output += "\(locationPrefix)At \(sourceLocation.fileName):\(sourceLocation.line):\(sourceLocation.column)\n"
          }
        }
      }
    }
    
    return output
  }
  
  /// Get the status icon for a test result.
  ///
  /// - Parameters:
  ///   - result: The test result.
  /// - Returns: The appropriate symbol string.
  private func _getStatusIcon(for result: _TestResult) -> String {
    switch result {
    case .passed:
      return Event.Symbol.pass(knownIssueCount: 0).stringValue(options: options.base)
    case .failed:
      return Event.Symbol.fail.stringValue(options: options.base)
    case .skipped:
      return Event.Symbol.skip.stringValue(options: options.base)
    }
  }
  
  /// Format a duration in seconds with exactly 2 decimal places.
  ///
  /// - Parameter duration: The duration to format.
  /// - Returns: A formatted duration string (e.g., "1.80s", "0.05s").
  private func _formatDuration(_ duration: Double) -> String {
    // Always format to exactly 2 decimal places
    let wholePart = Int(duration)
    let fractionalPart = Int((duration - Double(wholePart)) * 100 + 0.5) // Round to nearest hundredth
    
    // Handle rounding overflow (e.g., 0.999 -> 1.00)
    if fractionalPart >= 100 {
      return "\(wholePart + 1).00s"
    } else {
      let fractionalString = fractionalPart < 10 ? "0\(fractionalPart)" : "\(fractionalPart)"
      return "\(wholePart).\(fractionalString)s"
    }
  }
  
  /// Pad a test line with right-aligned duration.
  ///
  /// - Parameters:
  ///   - testLine: The test line to pad.
  ///   - duration: The duration string.
  /// - Returns: The padded test line with right-aligned duration.
  private func _padWithDuration(_ testLine: String, duration: String) -> String {
    if duration.isEmpty {
      return testLine
    }
    
    let targetWidth = 100
    let rightPart = "(\(duration))"
    let totalLeftLength = testLine.count
    let totalRightLength = rightPart.count
    
    if totalLeftLength + totalRightLength + 5 < targetWidth {
      let paddingLength = targetWidth - totalLeftLength - totalRightLength
      return "\(testLine)\(String(repeating: " ", count: paddingLength))\(rightPart)"
    } else {
      return "\(testLine) \(rightPart)"
    }
  }
  
  /// Check if a string contains Swift file pattern without using Foundation.
  ///
  /// - Parameters:
  ///   - string: The string to check.
  /// - Returns: True if the string contains ".swift:" pattern.
  private func _containsSwiftFile(_ string: String) -> Bool {
    let target = ".swift:"
    let targetLength = target.count
    let stringLength = string.count
    
    guard stringLength >= targetLength else { return false }
    
    for i in 0...(stringLength - targetLength) {
      let startIndex = string.index(string.startIndex, offsetBy: i)
      let endIndex = string.index(startIndex, offsetBy: targetLength)
      let substring = String(string[startIndex..<endIndex])
      if substring == target {
        return true
      }
    }
    return false
  }
  
  /// Get the fully qualified test name for a given test ID.
  ///
  /// This function traverses the hierarchy to build the full test name.
  ///
  /// - Parameters:
  ///   - testID: The ID of the test.
  ///   - context: The context containing the test hierarchy.
  /// - Returns: The fully qualified test name.
  private func _getFullyQualifiedTestName(testID: String, context: _Context) -> String {
    guard let keyPath = _findKeyPathForTestID(testID, in: context.testTree) else { return testID }
    
    var nameParts: [String] = []
    
    // Build the hierarchy path by traversing from root to leaf
    for i in 1...keyPath.count {
      let currentKeyPath = Array(keyPath.prefix(i))
      if let node = context.testTree[currentKeyPath] {
        let displayName = node.displayName ?? node.name
        nameParts.append(displayName)
      }
    }
    
    return nameParts.joined(separator: "/")
  }

  /// Get the fully qualified test name for a given test ID, including the file name.
  ///
  /// This function traverses the hierarchy to build the full test name in the format:
  /// ModuleName/FileName/"SuiteName"/"TestName"
  ///
  /// - Parameters:
  ///   - testID: The ID of the test.
  ///   - context: The context containing the test hierarchy.
  /// - Returns: The fully qualified test name with file name included.
  private func _getFullyQualifiedTestNameWithFile(testID: String, context: _Context) -> String {
    guard let keyPath = _findKeyPathForTestID(testID, in: context.testTree) else { return testID }
    
    // Get the source file name from the first issue
    var fileName = ""
    if let issues = context.testData[testID]?.issues, 
       let firstIssue = issues.first,
       let sourceLocation = firstIssue.sourceLocation {
      fileName = sourceLocation.fileName
    }
    
    var nameParts: [String] = []
    
    // Build the hierarchy path by traversing from root to leaf
    for i in 1...keyPath.count {
      let currentKeyPath = Array(keyPath.prefix(i))
      if let node = context.testTree[currentKeyPath] {
        let displayName = node.displayName ?? node.name
        
        // For non-module nodes (suites and tests), wrap in quotes
        if i > 1 {
          nameParts.append("\"\(displayName)\"")
        } else {
          // Module name - no quotes
          nameParts.append(displayName)
        }
      }
    }
    
    // Insert file name after module name if we have it
    if !fileName.isEmpty && nameParts.count > 0 {
      nameParts.insert(fileName, at: 1)
    }
    
    return nameParts.joined(separator: "/")
  }
}
