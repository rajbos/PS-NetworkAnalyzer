# GitHub Copilot Agent Usage Examples

This document provides practical examples of how to use the research and planner agents in your development workflow.

## Example 1: Adding a New Feature

### Scenario
You want to add network packet analysis functionality to the PS-NetworkAnalyzer project.

### Step 1: Research Phase
```
@research I need to implement network packet capture and analysis in PowerShell. 
What libraries and approaches are available?
```

**Expected Research Output:**
- Documentation on PowerShell networking capabilities
- Available .NET libraries for packet capture (e.g., SharpPcap)
- Best practices for network analysis tools
- Security considerations
- Code examples and patterns

### Step 2: Planning Phase
After the research agent completes, click the **"Create Implementation Plan"** button.

**Expected Planning Output:**
- Prerequisites (required libraries, permissions)
- Implementation tasks broken into phases
- Testing strategy
- Documentation requirements
- Potential challenges and mitigation

## Example 2: Technology Migration

### Scenario
You need to migrate from an older API to a new version.

### Step 1: Research
```
@research I need to migrate from .NET Framework 4.8 to .NET 8 for a PowerShell module. 
What are the breaking changes and migration steps?
```

### Step 2: Planning
The handoff automatically includes your research context:
- Breaking changes identified
- Migration path outlined
- Testing requirements specified
- Rollback strategy included

## Example 3: Performance Optimization

### Scenario
Your network analyzer is running slowly with large datasets.

### Research Query
```
@research What are the best practices for optimizing PowerShell performance 
when processing large network data sets?
```

### Planning Result
- Profiling approach
- Optimization techniques prioritized by impact
- Implementation order based on dependencies
- Benchmarking strategy

## Best Practices

### When to Use Research Agent
- ✅ Exploring new technologies or libraries
- ✅ Understanding best practices for a domain
- ✅ Finding solutions to unfamiliar problems
- ✅ Gathering documentation before implementation
- ✅ Comparing different approaches

### When to Use Planner Agent
- ✅ Breaking down complex features
- ✅ Creating implementation roadmaps
- ✅ Planning refactoring efforts
- ✅ Organizing multi-step work
- ✅ After receiving research findings

### Tips for Better Results

#### For Research Agent
1. **Be Specific**: Include technologies, versions, and context
   - ❌ "How do I do networking?"
   - ✅ "How do I capture TCP packets in PowerShell 7 on Windows?"

2. **State Your Goal**: Explain what you're trying to achieve
   - ✅ "I need to monitor network latency for troubleshooting"

3. **Mention Constraints**: Include relevant limitations
   - ✅ "Without requiring administrator privileges"
   - ✅ "Must work on Windows Server 2019+"

#### For Planner Agent
1. **Provide Context**: Share what you know about the codebase
   - ✅ "This is a PowerShell module with an existing test suite"

2. **Set Priorities**: Mention what's most important
   - ✅ "Performance is critical, but maintainability is more important"

3. **Define Success**: Clarify what "done" looks like
   - ✅ "Should handle 10,000 packets per second"

## Advanced Workflows

### Research → Plan → Research Cycle
Sometimes you need to iterate:

1. Initial research: `@research [broad topic]`
2. Create initial plan (handoff)
3. Identify knowledge gaps in plan
4. Follow-up research: `@research [specific gap]`
5. Refine plan with new information

### Direct Planning (Skip Research)
For well-understood tasks:

```
@planner Create an implementation plan for adding unit tests to the 
Get-NetworkLatency function using Pester framework.
```

### Research Without Planning
For learning or exploration:

```
@research What are the different network protocols I should consider 
for monitoring in a network analyzer tool?
```

## Troubleshooting

### Agent Not Available
- Ensure VS Code is up to date
- Verify GitHub Copilot extension is enabled
- Check that you're in the repository root
- Restart VS Code if needed

### Handoff Not Working
- Verify the YAML frontmatter in agent files is valid
- Check that both agent files exist in `.github/agents/`
- Ensure you're clicking the handoff button, not just mentioning the agent

### Poor Quality Output
- Provide more context in your prompts
- Break down complex requests into smaller queries
- Use the iteration approach (research → plan → refine)
- Be specific about your requirements and constraints

## Integration with Development Workflow

### Typical Development Flow

```
1. Issue/Requirement identified
   ↓
2. @research [gather context and documentation]
   ↓
3. Handoff → @planner [create implementation plan]
   ↓
4. Review plan, ask questions if needed
   ↓
5. Follow plan to implement
   ↓
6. Use @workspace or other agents for coding
   ↓
7. Test and validate
   ↓
8. (Optional) @research [troubleshooting or optimization]
```

### Combining with Other Agents

These agents work well with other GitHub Copilot agents:
- `@workspace`: For codebase-specific questions during implementation
- `@terminal`: For running commands from the plan
- `@vscode`: For IDE-specific tasks

Example:
```
After planning phase:
1. @planner creates the plan
2. @workspace help me implement the first task from the plan
3. @terminal run the tests specified in the plan
```

## Additional Resources

- [GitHub Copilot Documentation](https://docs.github.com/copilot)
- [VS Code Copilot Agents](https://code.visualstudio.com/docs/copilot/agents/overview)
- [Custom Agent Configuration](https://docs.github.com/en/copilot/reference/custom-agents-configuration)
