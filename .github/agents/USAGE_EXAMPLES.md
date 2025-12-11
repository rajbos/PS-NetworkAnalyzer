# GitHub Copilot Agent Usage Examples

This document provides practical examples of how to use the research and planner agents in your development workflow.

## Availability

These custom agents are available across all GitHub Copilot platforms:
- **VS Code** - Use via GitHub Copilot Chat with `@research` and `@planner`
- **GitHub.com** - Access through GitHub Copilot Coding Agent
- **GitHub CLI** - Use with `gh copilot` commands
- **Other IDEs** - JetBrains, Eclipse, Xcode (where Copilot is supported)

Simply invoke the agents using `@research` or `@planner` in any supported environment.

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
After the research agent completes, follow the instructions in its output to invoke the planner agent. The research agent will provide you with the exact command to use.

**Note**: Handoff buttons are not yet fully supported by the coding agent, so you'll need to manually invoke the next agent using the `@planner` command provided in the research output.

**Expected Planning Output:**
- Prerequisites (required libraries, permissions)
- Implementation tasks broken into phases
- Testing strategy
- Documentation requirements
- Potential challenges and mitigation

### Step 3: Implementation Phase
After the planner agent completes, follow the instructions in its output to invoke the implementation agent. The planner agent will provide you with the exact command to use.

**Note**: Similarly, you'll need to manually invoke the implementation agent using the `@implementation` command provided in the planner output.

**Expected Implementation Output:**
- Code changes written to the repository
- Tests executed and validated
- Build/compilation confirmed successful
- Documentation updated as needed
- Summary of what was implemented

## Example 2: Technology Migration

### Scenario
You need to migrate from an older API to a new version.

### Step 1: Research
```
@research I need to migrate from .NET Framework 4.8 to .NET 8 for a PowerShell module. 
What are the breaking changes and migration steps?
```

### Step 2: Planning
Use the `@planner` command provided in the research output to continue:
- Breaking changes identified
- Migration path outlined
- Testing requirements specified
- Rollback strategy included

### Step 3: Implementation
Use the `@implementation` command provided in the planner output to execute the migration:
- Code changes applied automatically
- Tests run to verify migration
- Issues debugged and resolved
- Final validation completed

## Example 3: Performance Optimization

### Scenario
Your network analyzer is running slowly with large datasets.

### Research Query
```
@research What are the best practices for optimizing PowerShell performance 
when processing large network data sets?
```

### Planning Result
Use the provided `@planner` command to create a plan:
- Profiling approach
- Optimization techniques prioritized by impact
- Implementation order based on dependencies
- Benchmarking strategy

### Implementation Execution
Use the provided `@implementation` command to execute optimizations:
- Code changes implemented
- Performance benchmarks run
- Results compared and validated
- Documentation updated with findings

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

### When to Use Implementation Agent
- ✅ Executing implementation plans
- ✅ Writing and modifying code
- ✅ Running tests and builds
- ✅ Validating changes work correctly
- ✅ After receiving a detailed plan

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

#### For Implementation Agent
1. **Trust the Plan**: Let it execute the plan from the planner
   - ✅ Use the `@implementation` command provided by the planner

2. **Monitor Progress**: Review what it's doing as it implements
   - ✅ Check commit messages and test results

3. **Provide Feedback**: If something isn't working, guide adjustments
   - ✅ "The tests are failing because of X, try Y instead"

## Advanced Workflows

### Research → Plan → Implement Workflow
The complete workflow for complex tasks:

1. Initial research: `@research [broad topic]`
2. Use the `@planner` command from research output to create initial plan
3. Review plan and refine if needed
4. Use the `@implementation` command from planner output to start implementation
5. Monitor progress and provide guidance as needed

### Research → Plan → Research Cycle
Sometimes you need to iterate before implementing:

1. Initial research: `@research [broad topic]`
2. Use the `@planner` command to create initial plan
3. Identify knowledge gaps in plan
4. Follow-up research: `@research [specific gap]`
5. Refine plan with new information
6. Start implementation once plan is solid

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
- **VS Code:** Ensure VS Code and the GitHub Copilot extension are up to date
- **GitHub.com:** Verify you have access to GitHub Copilot and the repository
- **GitHub CLI:** Ensure you're authenticated with `gh auth login` and have Copilot access
- Check that you're in the repository root
- Restart your IDE or refresh the page if needed

### Handoff Not Working
- **Note**: Handoff buttons are not yet fully supported by the coding agent
- Instead, use the `@agent` commands provided in each agent's output
- Each agent will provide the exact command to invoke the next agent
- Verify the YAML frontmatter in agent files is valid
- Check that all agent files exist in `.github/agents/`

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
3. Use @planner command from research output
   ↓
4. Review plan, ask questions if needed
   ↓
5. Use @implementation command from planner output
   ↓
6. Monitor progress, tests run automatically
   ↓
7. Changes committed and validated
   ↓
8. (Optional) @research [troubleshooting or optimization]
```

### Combining with Other Agents

These agents work well with other GitHub Copilot agents:
- `@workspace`: For codebase-specific questions during implementation
- `@terminal`: For running commands from the plan
- `@vscode`: For IDE-specific tasks (VS Code only)
- `@implementation`: For executing implementation plans

Example:
```
Complete automated workflow:
1. @research [gather information about the task]
2. Use @planner command from research output → creates detailed plan
3. Use @implementation command from planner output → executes the plan
4. Implementation agent writes code, runs tests, commits changes
5. Review and merge when complete

Manual workflow (when you want more control):
1. @planner creates the plan
2. @workspace help me implement the first task from the plan
3. @terminal run the tests specified in the plan
```

## Additional Resources

- [GitHub Copilot Documentation](https://docs.github.com/copilot)
- [VS Code Copilot Agents](https://code.visualstudio.com/docs/copilot/agents/overview)
- [Custom Agent Configuration](https://docs.github.com/en/copilot/reference/custom-agents-configuration)
