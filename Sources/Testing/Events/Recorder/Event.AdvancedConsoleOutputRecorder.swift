//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Foundation

extension Event {
  /// An advanced console output recorder that provides enhanced features like
  /// live progress reporting, hierarchical suite display, and improved formatting.
  ///
  /// This recorder builds upon the existing `ConsoleOutputRecorder` but adds:
  /// - Buffered hierarchical output maintaining tree structure during parallel execution
  /// - Issues displayed as sub-nodes under their parent tests
  /// - Proper Unicode box-drawing characters for tree visualization
  /// - Suite summaries "out-dented" to align with parent levels
  /// - Right-aligned timing information
  @_spi(Experimental)
  public struct AdvancedConsoleOutputRecorder: Sendable {
    /// Configuration options for the advanced console output recorder.
    public struct Options: Sendable {
      public var base: Event.ConsoleOutputRecorder.Options
      
      public var useHierarchicalOutput: Bool
      
      public init() {
        self.base = Event.ConsoleOutputRecorder.Options()
        self.useHierarchicalOutput = true
      }
    }
    
    /// The options for this recorder.
    public let options: Options
    
    public let write: @Sendable (String) -> Void
    
    private struct HierarchyNode: Sendable {
      let id: Test.ID
      let name: String
      let displayName: String?
      let isSuite: Bool
      var status: NodeStatus = .running
      var startTime: Test.Clock.Instant?
      var endTime: Test.Clock.Instant?
      var issues: [IssueInfo] = []
      var children: [HierarchyNode] = []
      
      struct IssueInfo: Sendable {
        let issue: Issue
        let isKnown: Bool
        let summary: String
      }
      
      enum NodeStatus: Sendable {
        case running
        case passed
        case failed
        case skipped
        case passedWithKnownIssues(count: Int)
        case passedWithWarnings(count: Int)
      }
    }
    
    private struct HierarchyContext: Sendable {
      var rootNodes: [HierarchyNode] = []
      
      var nodesByID: [Test.ID: Int] = [:] 
      
      var allNodes: [HierarchyNode] = []
      
      var completedSuites: [Test.ID] = []
      
      /// Track which suites have had all their children complete
      var suiteChildrenStatus: [Test.ID: (total: Int, completed: Int)] = [:]
      
      /// Buffer for collecting suite output before rendering
      var suiteBuffers: [Test.ID: String] = [:]
      
      /// Track test execution order for proper rendering
      var executionOrder: [Test.ID] = []
      
      /// Overall test statistics
      var overallStats = (passed: 0, failed: 0, skipped: 0, knownIssues: 0, warnings: 0, attachments: 0)
      
      /// Track test run timing
      var runStartTime: Test.Clock.Instant?
      var runEndTime: Test.Clock.Instant?
      
      /// Test target/module name for root node
      var testTargetName: String?
      var testTargetRootNode: HierarchyNode?
      
      /// Completed tests that are ready for rendering
      var completedTests: [Test.ID] = []
      
      /// Track suite completion to render hierarchically
      var suiteCompletionStatus: [Test.ID: (expected: Int, completed: Int)] = [:]
      
      /// Progress tracking
      var totalTestCount: Int = 0
      var completedTestCount: Int = 0
      var showProgressBar: Bool = true
      
      /// Buffer hierarchy output until completion
      var hierarchyBuffer: String = ""
      
      /// Simple progress tracking
      var isRunning: Bool = false
      var shouldShowSpinner: Bool = true
      var spinnerIndex: Int = 0
      var testCounter: Int = 0
      var startTime: Test.Clock.Instant?
    }
    
    /// The hierarchical context, protected by a lock for thread safety.
    private let _context = Locked(rawValue: HierarchyContext())
    
    /// Initialize the advanced console output recorder.
    public init(options: Options = Options(), writingUsing write: @escaping @Sendable (String) -> Void) {
      self.options = options
      self.write = write
    }
  }
}

extension Event.AdvancedConsoleOutputRecorder {
  /// Handle an event and produce hierarchical output.
  public func handle(_ event: borrowing Event, in eventContext: borrowing Event.Context) {
    if options.useHierarchicalOutput {
      handleWithHierarchy(event, in: eventContext)
    } else {
      // Fallback to regular console output
      let consoleRecorder = Event.ConsoleOutputRecorder(options: options.base, writingUsing: write)
      consoleRecorder.record(event, in: eventContext)
    }
  }
  
  private func handleWithHierarchy(_ event: borrowing Event, in eventContext: borrowing Event.Context) {
    switch event.kind {
    case .runStarted:
      let testTargetName = extractTestTargetNameFromEventContext(eventContext)
      let testCount = getTestCount(from: eventContext)
      
      _context.withLock { context in
        context.runStartTime = event.instant
        
        if !testTargetName.isEmpty {
          context.testTargetName = testTargetName
        }
        
        // Enable spinner mode
        context.isRunning = true
        context.shouldShowSpinner = true 
      }
      
      let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
      let tealColor = useColors ? "\u{001B}[96m" : ""  // teal (.default)
      let resetColor = useColors ? "\u{001B}[0m" : ""
      
      #if os(macOS)
      let runningSymbol = String(Event.Symbol.default.sfSymbolCharacter)
      #else
      let runningSymbol = String(Event.Symbol.default.unicodeCharacter)
      #endif
      
      let message = if testCount > 0 {
        "Running \(testCount) tests..."
      } else {
        "Running tests..."
      }
      
      write("\n\(tealColor)\(runningSymbol) \(resetColor)\(message)\n\n")
      
    case .testStarted:
      guard let test = eventContext.test else { return }
      handleTestStarted(test, at: event.instant)
      
    case .testEnded:
      guard let test = eventContext.test else { return }
      handleTestEnded(test, at: event.instant)
      renderTestResult(test)  
      
    case let .issueRecorded(issue):
      guard let test = eventContext.test else { return }
      handleIssueRecorded(test, issue: issue, at: event.instant)
      
    case .valueAttached(let attachment):
      guard let test = eventContext.test else { return }
      handleValueAttached(test, attachment: attachment, at: event.instant)
      
    case .runEnded:
      _context.withLock { context in
        context.runEndTime = event.instant
        context.isRunning = false
        context.shouldShowSpinner = false
        
        if let testTargetRootIndex = context.rootNodes.firstIndex(where: { $0.name == context.testTargetName }) {
          context.allNodes[testTargetRootIndex].endTime = event.instant
        }
        
        // Clear spinner and show buffered hierarchy
        write("\r\u{001B}[K\n") 
        write(context.hierarchyBuffer)
      }
      
      renderFinalSummary()
      
    case .testSkipped:
      if let test = eventContext.test {
        handleTestSkipped(test, at: event.instant)
        renderTestResult(test)
      }
      
    case .testCaseStarted, .testCaseEnded, .expectationChecked, .iterationStarted, .iterationEnded:
      break
      
    default:
      handleOtherEvent(event, in: eventContext)
    }
  }
  
  private func getTestCount(from eventContext: borrowing Event.Context) -> Int {
    // Tests will be counted dynamically as they start
    return 0
  }
  
  private func updateProgressBar() {
    _context.withLock { context in
      guard context.showProgressBar && context.totalTestCount > 0 else { return }
      
      let completed = max(0, context.completedTestCount)
      let total = max(1, context.totalTestCount) 
      let safeCompleted = min(completed, total)
      let percentage = min(100, max(0, (safeCompleted * 100) / total))
      
      // Create progress bar
      let barWidth = 30
      let filledWidth = max(0, min(barWidth, (percentage * barWidth) / 100))
      let emptyWidth = max(0, barWidth - filledWidth)
      
      guard filledWidth >= 0 && emptyWidth >= 0 && (filledWidth + emptyWidth) <= barWidth else {
        write("\r\u{001B}[K")
        write("Tests: \(safeCompleted)/\(total)")
        return
      }
      
      let filled = String(repeating: "█", count: filledWidth)
      let empty = String(repeating: "░", count: emptyWidth)
      
      let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
      let progressColor = useColors ? "\u{001B}[96m" : "" 
      let resetColor = useColors ? "\u{001B}[0m" : ""
      
      write("\r\u{001B}[K")
      write("\(progressColor)[\(filled)\(empty)] \(percentage)% (\(safeCompleted)/\(total))\(resetColor)")
    }
  }
  
  private func renderCompleteHierarchy() {
    _context.withLock { context in
      // Render the complete hierarchical tree
      for (index, rootNode) in context.rootNodes.enumerated() {
        let isLastRoot = index == context.rootNodes.count - 1
        let hierarchyOutput = renderNodeTree(rootNode, depth: 0, isLast: isLastRoot, parentPrefix: "", nodeStatusLookup: [:])
        write(hierarchyOutput)
      }
    }
  }
  
  private func extractTestTargetNameFromEventContext(_ eventContext: borrowing Event.Context) -> String {
    if let test = eventContext.test {
      return extractTestTargetName(from: test.id)
    }
    return ""
  }
  
  private func renderTestResult(_ test: Test) {
    _context.withLock { context in
      guard let nodeIndex = context.nodesByID[test.id],
            nodeIndex < context.allNodes.count else { 
        renderTestResultFallback(test)
        return 
      }
      
      let node = context.allNodes[nodeIndex]
      
      let hierarchyPath = buildHierarchyPath(for: test.id)
      let depth = hierarchyPath.count
      let baseIndent = String(repeating: " ", count: depth * 3)
      
      let symbolWithColor = getSymbolWithColorForNode(node)
      let name = node.displayName ?? node.name
      let timing = formatTiming(node)
      let rightAlignedTiming = formatRightAlignedTiming(timing, contentPrefix: "\(baseIndent)├─ \(symbolWithColor)\(name)")
      
      let output = "\(baseIndent)├─ \(symbolWithColor)\(name)\(rightAlignedTiming)\n"
      
      if context.isRunning && context.shouldShowSpinner {
        // Buffer output during spinner mode
        context.hierarchyBuffer += output
        
        // Show issues in buffer too
        if !node.issues.isEmpty {
          let issueIndent = String(repeating: " ", count: (depth + 1) * 3)
          for (index, issue) in node.issues.enumerated() {
            let isLastIssue = index == node.issues.count - 1
            let issueTreePrefix = isLastIssue ? "╰─ " : "├─ "
            let issueSymbol = getSymbolWithColorForIssue(issue)
            context.hierarchyBuffer += "\(issueIndent)\(issueTreePrefix)\(issueSymbol)\(issue.summary)\n"
          }
        }
        
        context.testCounter += 1
        
        // Update spinner on its own line
        let spinnerChars = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        let spinnerChar = spinnerChars[context.spinnerIndex % spinnerChars.count]
        context.spinnerIndex = (context.spinnerIndex + 1) % spinnerChars.count
        
        let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
        let spinnerColor = useColors ? "\u{001B}[96m" : ""  // teal
        let resetColor = useColors ? "\u{001B}[0m" : ""
        
        write("\r\u{001B}[K")
        write("\(spinnerColor)\(spinnerChar) Running tests... (\(context.testCounter) completed)\(resetColor)")
      } else {
        write(output)
        
        if !node.issues.isEmpty {
          let issueIndent = String(repeating: " ", count: (depth + 1) * 3)
          for (index, issue) in node.issues.enumerated() {
            let isLastIssue = index == node.issues.count - 1
            let issueTreePrefix = isLastIssue ? "╰─ " : "├─ "
            let issueSymbol = getSymbolWithColorForIssue(issue)
            write("\(issueIndent)\(issueTreePrefix)\(issueSymbol)\(issue.summary)\n")
          }
        }
      }
    }
  }
  
  private func renderTestResultFallback(_ test: Test) {
    let status: HierarchyNode.NodeStatus = .passed
    let symbolWithColor = getSymbolWithColorForStatus(status)
    let name = test.displayName ?? test.name
    write("├─ \(symbolWithColor)\(name)\n")
  }
  
  private func getSymbolWithColorForStatus(_ status: HierarchyNode.NodeStatus) -> String {
    let symbol = getEventSymbolForNodeStatus(status)
    return applyCustomColorToSymbol(symbol, for: status)
  }
  
  private func buildHierarchyPath(for testID: Test.ID) -> [String] {
    var path: [String] = []
    var currentID: Test.ID? = testID.parent
    
    while let parentID = currentID {
      let parentName = extractNameFromTestID(parentID)
      path.insert(parentName, at: 0)
      currentID = parentID.parent
    }
    
    return path
  }
  
  private func extractNameFromTestID(_ testID: Test.ID) -> String {
    let idString = testID.description
    let components = idString.components(separatedBy: ".")
    return components.last ?? idString
  }
  
  private func calculateTestDepth(_ testID: Test.ID, in context: HierarchyContext) -> Int {
    var depth = 1 
    var currentID: Test.ID? = testID.parent
    
    while let parentID = currentID {
      depth += 1
      currentID = parentID.parent
    }
    
    return depth
  }
  
  private func handleTestStarted(_ test: Test, at instant: Test.Clock.Instant) {
    _context.withLock { context in
      if context.testTargetRootNode == nil {
        let testTargetName = extractTestTargetName(from: test.id)
        context.testTargetName = testTargetName
        
        let rootNode = HierarchyNode(
          id: Test.ID(type: String.self),
          name: testTargetName,
          displayName: testTargetName,
          isSuite: true,
          startTime: instant
        )
        
        context.allNodes.append(rootNode)
        let rootIndex = context.allNodes.count - 1
        context.testTargetRootNode = context.allNodes[rootIndex]
        context.rootNodes.append(context.allNodes[rootIndex])
      }
      
      let node = HierarchyNode(
        id: test.id,
        name: test.name,
        displayName: test.displayName,
        isSuite: test.isSuite,
        startTime: instant
      )
      
      context.allNodes.append(node)
      let currentIndex = context.allNodes.count - 1
      context.nodesByID[test.id] = currentIndex
      context.executionOrder.append(test.id)
      
      // Add to parent's children or as child of test target root
      if let parentID = test.id.parent {
        var actualParentID = parentID
        if !test.isSuite {
          var currentID = parentID
          while let parent = currentID.parent {
            if context.nodesByID[parent] != nil {
              actualParentID = parent
              break
            }
            currentID = parent
          }
        }
        
        if let parentIndex = context.nodesByID[actualParentID] {
          // Add this node as a child of the parent (modify the parent directly in the array)
          context.allNodes[parentIndex].children.append(context.allNodes[currentIndex])
        } else {
          if isTopLevelSuite(test, targetName: context.testTargetName ?? "") {
            if let rootIndex = context.rootNodes.firstIndex(where: { $0.name == context.testTargetName }) {
              context.allNodes[rootIndex].children.append(context.allNodes[currentIndex])
              context.rootNodes[rootIndex] = context.allNodes[rootIndex]
            }
          }
        }
      } else {
        if let rootIndex = context.rootNodes.firstIndex(where: { $0.name == context.testTargetName }) {
          context.allNodes[rootIndex].children.append(context.allNodes[currentIndex])
          context.rootNodes[rootIndex] = context.allNodes[rootIndex]
        }
      }
    }
  }
  
  private func extractTestTargetName(from testID: Test.ID) -> String {
    let components = testID.description.components(separatedBy: ".")
    return components.first ?? "TestTarget"
  }
  
  private func isTopLevelSuite(_ test: Test, targetName: String) -> Bool {
    
    if !test.isSuite {
      return false
    }
    
    let testIDString = test.id.description
    let components = testIDString.components(separatedBy: ".")
    
    if components.count >= 2 && components[0] == targetName {
      return true
    }
    
    return false
  }
  
  private func handleTestEnded(_ test: Test, at instant: Test.Clock.Instant) {
    _context.withLock { context in
      guard let nodeIndex = context.nodesByID[test.id] else { return }
      guard nodeIndex < context.allNodes.count else { return } // Safety check
      
      context.allNodes[nodeIndex].endTime = instant
      
      let node = context.allNodes[nodeIndex]
      let knownIssueCount = node.issues.filter { $0.isKnown }.count
      let warningCount = node.issues.filter { $0.issue.severity == .warning }.count
      let failureCount = node.issues.filter { !$0.isKnown && $0.issue.severity == .error }.count
      let attachmentCount = node.issues.filter { issueInfo in
        if case .valueAttachmentFailed = issueInfo.issue.kind {
          return true
        }
        return false
      }.count
      
      if failureCount > 0 {
        context.allNodes[nodeIndex].status = .failed
      } else if knownIssueCount > 0 {
        context.allNodes[nodeIndex].status = .passedWithKnownIssues(count: knownIssueCount)
      } else if warningCount > 0 {
        context.allNodes[nodeIndex].status = .passedWithWarnings(count: warningCount)
      } else {
        context.allNodes[nodeIndex].status = .passed
      }
      
      if !test.isSuite {
        switch context.allNodes[nodeIndex].status {
        case .passed:
          context.overallStats.passed += 1
        case .failed:
          context.overallStats.failed += 1
        case .skipped:
          context.overallStats.skipped += 1
        case .passedWithKnownIssues(let count):
          context.overallStats.passed += 1
          context.overallStats.knownIssues += count
        case .passedWithWarnings(let count):
          context.overallStats.passed += 1
          context.overallStats.warnings += count
        case .running:
          break
        }
        context.overallStats.attachments += attachmentCount
      }
      
      // Mark test as completed 
      context.completedTests.append(test.id)
      
      // Handle suite completion tracking - don't render individual tests here
      // Wait for all tests to complete so we can show final status icons
      if test.isSuite {
        // Suite completed - update the test target root end time if needed
        if let testTargetRootIndex = context.rootNodes.firstIndex(where: { $0.name == context.testTargetName }) {
          context.allNodes[testTargetRootIndex].endTime = instant
        }
      }
      
      // Only render at the very end when run ends to show final status
    }
  }
  
  private func handleIssueRecorded(_ test: Test, issue: Issue, at instant: Test.Clock.Instant) {
    _context.withLock { context in
      guard let nodeIndex = context.nodesByID[test.id] else { return }
      guard nodeIndex < context.allNodes.count else { return } // Safety check
      
      let issueInfo = HierarchyNode.IssueInfo(
        issue: issue,
        isKnown: issue.isKnown,
        summary: formatIssueSummary(issue)
      )
      
      context.allNodes[nodeIndex].issues.append(issueInfo)
    }
  }
  
  private func handleValueAttached(_ test: Test, attachment: Attachment<AnyAttachable>, at instant: Test.Clock.Instant) {
    _context.withLock { context in
      guard let nodeIndex = context.nodesByID[test.id] else { return }
      guard nodeIndex < context.allNodes.count else { return }
      
      context.overallStats.attachments += 1
    }
  }
  
  private func applyCustomColorToAttachment(_ symbol: Event.Symbol) -> String {
    let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
    
    #if os(macOS)
    let symbolChar = String(symbol.sfSymbolCharacter)
    #else
    let symbolChar = String(symbol.unicodeCharacter)
    #endif
    
    if useColors {
      let colorCode = "\u{001B}[34m"   // blue
      return "\(colorCode)\(symbolChar) \u{001B}[0m"
    } else {
      return "\(symbolChar) "
    }
  }
  
  private func handleTestSkipped(_ test: Test, at instant: Test.Clock.Instant) {
    _context.withLock { context in
      let node = HierarchyNode(
        id: test.id,
        name: test.name,
        displayName: test.displayName,
        isSuite: test.isSuite,
        startTime: instant,
        endTime: instant
      )
      
      context.allNodes.append(node)
      let currentIndex = context.allNodes.count - 1
      context.nodesByID[test.id] = currentIndex
      context.allNodes[currentIndex].status = .skipped
      
      if !test.isSuite {
        context.overallStats.skipped += 1
      }
      
      if let parentID = test.id.parent {
        var actualParentID = parentID
        if !test.isSuite {
          var currentID = parentID
          while let parent = currentID.parent {
            if context.nodesByID[parent] != nil {
              actualParentID = parent
              break
            }
            currentID = parent
          }
        }
        
        if let parentIndex = context.nodesByID[actualParentID] {
          context.allNodes[parentIndex].children.append(context.allNodes[currentIndex])
        } else {
          context.rootNodes.append(context.allNodes[currentIndex])
        }
      } else {
        context.rootNodes.append(context.allNodes[currentIndex])
      }
    }
  }
  
  private func handleOtherEvent(_ event: borrowing Event, in eventContext: borrowing Event.Context) {
    let consoleRecorder = Event.ConsoleOutputRecorder(options: options.base, writingUsing: write)
    consoleRecorder.record(event, in: eventContext)
  }
  
  private func formatRightAlignedTiming(_ timing: String, contentPrefix: String) -> String {
    guard !timing.isEmpty else { return "" }
    
    let columnWidth = 150
    
    let cleanPrefix = contentPrefix.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
    
    let prefixLength = cleanPrefix.count
    let timingLength = timing.count
    let availableSpace = columnWidth - prefixLength - timingLength
    
    if availableSpace <= 1 {
      return " \(timing)"
    }
    
    return String(repeating: " ", count: availableSpace) + timing
  }
  
  private func renderNodeTree(_ node: HierarchyNode, depth: Int, isLast: Bool, parentPrefix: String, nodeStatusLookup: [Test.ID: HierarchyNode]) -> String {
    var output = ""
    
    // Build the tree prefix for this level
    let currentPrefix = buildTreePrefix(depth: depth, isLast: false, parentPrefix: parentPrefix)
    let finalPrefix = buildTreePrefix(depth: depth, isLast: true, parentPrefix: parentPrefix)
    
    if !node.isSuite {
      let currentNode = nodeStatusLookup[node.id] ?? node
      let symbolWithColor = getSymbolWithColorForNode(currentNode)
      let name = currentNode.displayName ?? currentNode.name
      let timing = formatTiming(currentNode)
      let rightAlignedTiming = formatRightAlignedTiming(timing, contentPrefix: "\(currentPrefix)\(symbolWithColor)\(name)")
      
      output += "\(currentPrefix)\(symbolWithColor)\(name)\(rightAlignedTiming)\n"
      
      if !currentNode.issues.isEmpty {
        for (index, issue) in currentNode.issues.enumerated() {
          let isLastIssue = index == currentNode.issues.count - 1
          let issuePrefix = buildTreePrefix(depth: depth + 1, isLast: isLastIssue, parentPrefix: currentPrefix)
          let issueSymbol = getSymbolWithColorForIssue(issue)
          output += "\(issuePrefix)\(issueSymbol)\(issue.summary)\n"
        }
      }
    } else {
      let suiteName = node.displayName ?? node.name
      output += "\(currentPrefix)\(suiteName)\n"
      
      // Render all children (test cases and sub-suites)
      for (_, child) in node.children.enumerated() {
        let childParentPrefix = buildParentPrefix(currentPrefix)
        
        output += renderNodeTree(child, depth: depth + 1, isLast: false, parentPrefix: childParentPrefix, nodeStatusLookup: nodeStatusLookup)
      }
      
      let stats = calculateSuiteStatistics(node)
      if stats.passed > 0 || stats.failed > 0 || stats.skipped > 0 || stats.knownIssues > 0 || stats.warnings > 0 {
        let summary = generateSuiteSummary(node, stats: stats)
        let suiteTiming = formatTiming(node)
        let summaryRightAligned = formatRightAlignedTiming(suiteTiming, contentPrefix: "\(finalPrefix)\(summary.icon)\(summary.text)")
        output += "\(finalPrefix)\(summary.icon)\(summary.text)\(summaryRightAligned)\n"
      }
    }
    
    return output
  }
  
  private func buildTreePrefix(depth: Int, isLast: Bool, parentPrefix: String) -> String {
    if depth == 0 {
      return ""
    }
    
    let connector = isLast ? "╰─ " : "├─ "
    return "\(parentPrefix)\(connector)"
  }
  
  private func buildParentPrefix(_ currentPrefix: String) -> String {
    let cleanPrefix = currentPrefix.replacingOccurrences(of: "├─ ", with: "│  ")
                                  .replacingOccurrences(of: "╰─ ", with: "   ")
    return cleanPrefix
  }
  
  private func renderIssue(_ issue: HierarchyNode.IssueInfo, prefix: String) -> String {
    let symbolWithColor = getSymbolWithColorForIssue(issue)
    return "\(prefix)\(symbolWithColor) \(issue.summary)\n"
  }
  
  private func getSymbolWithColorForNode(_ node: HierarchyNode) -> String {
    let symbol = getEventSymbolForNodeStatus(node.status)
    return applyCustomColorToSymbol(symbol, for: node.status)
  }
  
  private func getSymbolWithColorForIssue(_ issue: HierarchyNode.IssueInfo) -> String {
    let symbol = getEventSymbolForIssue(issue)
    return applyCustomColorToIssue(symbol, for: issue)
  }
  
  private func applyCustomColorToSymbol(_ symbol: Event.Symbol, for status: HierarchyNode.NodeStatus) -> String {
    let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
    
    #if os(macOS)
    let symbolChar = String(symbol.sfSymbolCharacter)
    #else
    let symbolChar = String(symbol.unicodeCharacter)
    #endif
    
    if useColors {
      let colorCode = getColorForNodeStatus(status)
      return "\(colorCode)\(symbolChar) \u{001B}[0m"
    } else {
      return "\(symbolChar) "
    }
  }
  
  private func applyCustomColorToIssue(_ symbol: Event.Symbol, for issue: HierarchyNode.IssueInfo) -> String {
    let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
    
    #if os(macOS)
    let symbolChar = String(symbol.sfSymbolCharacter)
    #else
    let symbolChar = String(symbol.unicodeCharacter)
    #endif
    
    if useColors {
      let colorCode = getColorForIssue(issue)
      return "\(colorCode)\(symbolChar) \u{001B}[0m"
    } else {
      return "\(symbolChar) "
    }
  }
  
  private func getColorForNodeStatus(_ status: HierarchyNode.NodeStatus) -> String {
    switch status {
    case .running:
      return "\u{001B}[96m"     // teal (.default)
    case .passed:
      return "\u{001B}[92m"     // green (.pass with no known issues)
    case .failed:
      return "\u{001B}[91m"     // red (.fail)
    case .skipped:
      return "\u{001B}[95m"     // purple (.skip)
    case .passedWithKnownIssues(_):
      return "\u{001B}[90m"     // gray (.pass with known issues)
    case .passedWithWarnings(_):
      return "\u{001B}[93m"     // yellow (.passWithWarnings)
    }
  }
  
  private func getColorForIssue(_ issue: HierarchyNode.IssueInfo) -> String {
    if issue.isKnown {
      return "\u{001B}[90m"     // gray for known issues
    } else {
      switch issue.issue.kind {
      case .expectationFailed(_):
        return "\u{001B}[33m"     // brown for differences (.difference)
      case .errorCaught(_):
        return "\u{001B}[91m"     // red for errors (.fail)
      case .unconditional:
        return "\u{001B}[93m"     // orange for warnings (.warning)
      case .timeLimitExceeded(_):
        return "\u{001B}[91m"     // red for time limit (.fail)
      case .apiMisused:
        return "\u{001B}[93m"     // orange for API misuse (.warning)
      case .knownIssueNotRecorded:
        return "\u{001B}[93m"     // orange for known issue not recorded (.warning)
      case .system:
        return "\u{001B}[91m"     // red for system errors (.fail)
      case .valueAttachmentFailed(_):
        return "\u{001B}[34m"     // blue for attachments (.attachment)
      case .confirmationMiscounted(_, _):
        return "\u{001B}[33m"     // brown for confirmation differences (.difference)
      }
    }
  }
  
  private func getSymbolCharacter(_ symbol: Event.Symbol) -> String {
    #if os(macOS)
    return String(symbol.sfSymbolCharacter)
    #else
    return String(symbol.unicodeCharacter)
    #endif
  }
  
  private func getEventSymbolForNodeStatus(_ status: HierarchyNode.NodeStatus) -> Event.Symbol {
    switch status {
    case .running:
      return .default 
    case .passed:
      return .pass(knownIssueCount: 0)
    case .failed:
      return .fail
    case .skipped:
      return .skip
    case .passedWithKnownIssues(let count):
      return .pass(knownIssueCount: count)
    case .passedWithWarnings(_):
      return .passWithWarnings
    }
  }
  
  private func getEventSymbolForIssue(_ issue: HierarchyNode.IssueInfo) -> Event.Symbol {
    if issue.isKnown {
      return .pass(knownIssueCount: 1) 
    } else {
      switch issue.issue.kind {
      case .expectationFailed(_):
        return .difference
      case .errorCaught(_):
        return .fail
      case .unconditional:
        return .warning
      case .timeLimitExceeded(_):
        return .fail
      case .apiMisused:
        return .warning
      case .knownIssueNotRecorded:
        return .warning
      case .system:
        return .fail
      case .valueAttachmentFailed(_):
        return .attachment
      case .confirmationMiscounted(_, _):
        return .difference
      }
    }
  }
  
  private func formatTiming(_ node: HierarchyNode) -> String {
    guard let startTime = node.startTime, let endTime = node.endTime else {
      return ""
    }
    
    guard startTime <= endTime else {
      return " (0.000s)"
    }
    
    let duration = startTime.descriptionOfDuration(to: endTime)
    return " (\(duration))"
  }
  
  private func formatIssueSummary(_ issue: Issue) -> String {
    let summary: String
    
    if case let .expectationFailed(expectation) = issue.kind {
      let description = expectation.evaluatedExpression.expandedDescription()
      if description.count > 80 {
        summary = "Expectation failed: \(String(description.prefix(77)))..."
      } else {
        summary = "Expectation failed: \(description)"
      }
    } else if case let .errorCaught(error) = issue.kind {
      summary = "Error: \(String(describing: error))"
    } else if case .unconditional = issue.kind {
      summary = "Issue recorded"
    } else if case let .timeLimitExceeded(timeLimitComponents) = issue.kind {
      summary = "Time limit exceeded: \(TimeValue(timeLimitComponents))"
    } else if case .apiMisused = issue.kind {
      summary = "API misuse"
    } else if case .knownIssueNotRecorded = issue.kind {
      summary = "Known issue not recorded"
    } else if case .system = issue.kind {
      summary = "System error"
    } else if case let .valueAttachmentFailed(error) = issue.kind {
      summary = "Attachment error: \(String(describing: error))"
    } else if case let .confirmationMiscounted(actual, expected) = issue.kind {
      summary = "Confirmation miscounted: \(actual) actual, \(expected) expected"
    } else {
      summary = issue.comments.first?.rawValue ?? "Issue recorded"
    }
    
    return summary
  }
  
  private func calculateSuiteStatistics(_ suite: HierarchyNode) -> (passed: Int, failed: Int, skipped: Int, knownIssues: Int, warnings: Int) {
    var passed = 0, failed = 0, skipped = 0, knownIssues = 0, warnings = 0
    
    func countNode(_ node: HierarchyNode) {
      if !node.isSuite {
        switch node.status {
        case .passed:
          passed += 1
        case .failed:
          failed += 1
        case .skipped:
          skipped += 1
        case .passedWithKnownIssues(let count):
          passed += 1
          knownIssues += count
        case .passedWithWarnings(let count):
          passed += 1
          warnings += count
        case .running:
          break
        }
      }
      
      for child in node.children {
        countNode(child)
      }
    }
    
    countNode(suite)
    return (passed, failed, skipped, knownIssues, warnings)
  }
  
  private func generateSuiteSummary(_ suite: HierarchyNode, stats: (passed: Int, failed: Int, skipped: Int, knownIssues: Int, warnings: Int)) -> (icon: String, text: String) {
    let eventSymbol: Event.Symbol
    if stats.failed > 0 {
      eventSymbol = .fail
    } else if stats.warnings > 0 {
      eventSymbol = .passWithWarnings
    } else if stats.skipped > 0 {
      eventSymbol = .skip
    } else {
      eventSymbol = .pass(knownIssueCount: 0)
    }
    
    let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
    
    let symbolWithColor: String
    if useColors {
      let colorCode = getColorForSummarySymbol(eventSymbol)
      symbolWithColor = "\(colorCode)\(getSymbolCharacter(eventSymbol))\u{001B}[0m"
    } else {
      symbolWithColor = getSymbolCharacter(eventSymbol)
    }
    
    // Generate summary text in format: "X failed, Y passed in Z.ZZs"
    var parts: [String] = []
    
    // Order matters: failed first, then passed, then skipped
    if stats.failed > 0 {
      parts.append("\(stats.failed) failed")
    }
    if stats.passed > 0 {
      parts.append("\(stats.passed) passed")
    }
    if stats.skipped > 0 {
      parts.append("\(stats.skipped) skipped")
    }
    
    let summaryText = parts.joined(separator: ", ")
    let duration = formatTiming(suite).trimmingCharacters(in: CharacterSet(charactersIn: " ()"))
    let fullText = summaryText.isEmpty ? "in \(duration)" : "\(summaryText) in \(duration)"
    
    return (icon: symbolWithColor, text: fullText)
  }
  
  private func getColorForSummarySymbol(_ symbol: Event.Symbol) -> String {
    switch symbol {
    case .pass(_):
      return "\u{001B}[92m"     // green
    case .fail:
      return "\u{001B}[91m"     // red
    case .skip:
      return "\u{001B}[95m"     // purple
    case .passWithWarnings:
      return "\u{001B}[93m"     // yellow
    case .warning:
      return "\u{001B}[93m"     // orange 
    case .difference:
      return "\u{001B}[33m"     // brown
    case .details:
      return "\u{001B}[94m"     // blue
    case .attachment:
      return "\u{001B}[34m"     // blue
    case .default:
      return "\u{001B}[96m"     // teal
    }
  }
  
  private func renderFinalSummary() {
    _context.withLock { context in
      var actualStats = (passed: 0, failed: 0, skipped: 0, knownIssues: 0, warnings: 0, attachments: 0)
      
      for node in context.allNodes {
        if !node.isSuite {
          switch node.status {
          case .passed:
            actualStats.passed += 1
          case .failed:
            actualStats.failed += 1
          case .skipped:
            actualStats.skipped += 1
          case .passedWithKnownIssues(let count):
            actualStats.passed += 1
            actualStats.knownIssues += count
          case .passedWithWarnings(let count):
            actualStats.passed += 1
            actualStats.warnings += count
          case .running:
            break
          }
        }
      }
      
      actualStats.attachments = context.overallStats.attachments
      
      // Calculate real test run duration with safety checks
      let duration: String
      if let startTime = context.runStartTime, let endTime = context.runEndTime {
        if startTime <= endTime {
          let durationString = startTime.descriptionOfDuration(to: endTime)
          duration = durationString
        } else {
          duration = "0.000 seconds"
        }
      } else {
        duration = "unknown duration"
      }
      
      var output = "\nTests completed in \(duration)  ["
      
      let useColors = options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4
      var summaryParts: [String] = []
      
      if actualStats.passed > 0 {
        if useColors {
          summaryParts.append("\u{001B}[92m\(getSymbolCharacter(.pass(knownIssueCount: 0)))\u{001B}[0m \(actualStats.passed)")
        } else {
          summaryParts.append("\(getSymbolCharacter(.pass(knownIssueCount: 0))) \(actualStats.passed)")
        }
      }
      
      if actualStats.failed > 0 {
        if useColors {
          summaryParts.append("\u{001B}[91m\(getSymbolCharacter(.fail))\u{001B}[0m \(actualStats.failed)")
        } else {
          summaryParts.append("\(getSymbolCharacter(.fail)) \(actualStats.failed)")
        }
      }
      
      if actualStats.warnings > 0 {
        if useColors {
          summaryParts.append("\u{001B}[93m\(getSymbolCharacter(.warning))\u{001B}[0m \(actualStats.warnings)")
        } else {
          summaryParts.append("\(getSymbolCharacter(.warning)) \(actualStats.warnings)")
        }
      }
      
      if actualStats.skipped > 0 {
        if useColors {
          summaryParts.append("\u{001B}[95m\(getSymbolCharacter(.skip))\u{001B}[0m \(actualStats.skipped)")
        } else {
          summaryParts.append("\(getSymbolCharacter(.skip)) \(actualStats.skipped)")
        }
      }
      
      if actualStats.knownIssues > 0 {
        if useColors {
          summaryParts.append("\u{001B}[90m\(getSymbolCharacter(.pass(knownIssueCount: 1)))\u{001B}[0m \(actualStats.knownIssues)")
        } else {
          summaryParts.append("\(getSymbolCharacter(.pass(knownIssueCount: 1))) \(actualStats.knownIssues)")
        }
      }
      
      if actualStats.attachments > 0 {
        if useColors {
          summaryParts.append("\u{001B}[34m\(getSymbolCharacter(.attachment))\u{001B}[0m \(actualStats.attachments)")
        } else {
          summaryParts.append("\(getSymbolCharacter(.attachment)) \(actualStats.attachments)")
        }
      }
      
      output += summaryParts.joined(separator: ", ")
      output += "]\n"
      
      if actualStats.failed > 0 {
        if options.base.useANSIEscapeCodes && options.base.ansiColorBitDepth >= 4 {
          output += "\n\u{001B}[91mFailure explanation - see details below\u{001B}[0m\n"
        } else {
          output += "\nFailure explanation - see details below\n"
        }
      }
      
      write(output)
    }
  }
} 