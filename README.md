# PS-NetworkAnalyzer

## GitHub Copilot Agent Mode

This repository includes custom GitHub Copilot agents to enhance your development workflow in VS Code.

### Available Agents

#### Research Agent (`@research`)
A specialized agent that gathers documentation, references, and technical information from the internet to analyze tasks and provide comprehensive context.

**Use cases:**
- Researching new technologies or APIs
- Finding best practices and implementation patterns
- Gathering documentation for unfamiliar libraries
- Understanding technical requirements

**How to use:**
1. Open GitHub Copilot Chat in VS Code
2. Use `@research` followed by your question or task
3. The agent will gather relevant documentation and references
4. When ready, click "Create Implementation Plan" to hand off to the planner

#### Planner Agent (`@planner`)
A strategic planning agent that creates detailed implementation plans with step-by-step tasks based on research findings and requirements.

**Use cases:**
- Breaking down complex features into tasks
- Creating implementation roadmaps
- Organizing development work
- Planning refactoring efforts

**How to use:**
1. Use `@planner` directly with your requirements
2. Or receive a handoff from the research agent
3. Review the generated implementation plan
4. Use it to guide your development work

### Agent Workflow

The recommended workflow combines both agents:

```
1. @research "I need to implement [feature/technology]"
   ↓
   Agent researches documentation, best practices, examples
   ↓
2. Click "Create Implementation Plan" button
   ↓
   @planner receives research findings and creates detailed plan
   ↓
3. Follow the plan to implement the feature
```

### Setup

These agents are automatically available when you:
1. Open this repository in VS Code
2. Have GitHub Copilot enabled
3. The agent files are located in `.github/agents/`

No additional configuration is needed!