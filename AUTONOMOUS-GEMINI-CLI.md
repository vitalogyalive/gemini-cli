# Maximizing Autonomy with Gemini CLI

A comprehensive guide to configuring Gemini CLI for maximum autonomous operation
— from zero-confirmation tool execution to self-healing agent loops, Jira
integration, browser validation, and background agents.

---

## Table of Contents

1. [Approval Modes & YOLO Mode](#1-approval-modes--yolo-mode)
2. [Policy Engine for Fine-Grained Auto-Approval](#2-policy-engine-for-fine-grained-auto-approval)
3. [MCP Servers: Extend Capabilities](#3-mcp-servers-extend-capabilities)
4. [Browser Agent: Autonomous Web Validation](#4-browser-agent-autonomous-web-validation)
5. [Custom Subagents: Domain Specialists](#5-custom-subagents-domain-specialists)
6. [Hooks: Automated Guardrails](#6-hooks-automated-guardrails)
7. [Skills: On-Demand Expertise](#7-skills-on-demand-expertise)
8. [Plan Mode: Safe Planning Before Acting](#8-plan-mode-safe-planning-before-acting)
9. [A2A Server: Background Agents](#9-a2a-server-background-agents)
10. [Non-Interactive / Headless Mode](#10-non-interactive--headless-mode)
11. [Full Autonomous Configuration](#11-full-autonomous-configuration)
12. [Example Autonomous Workflows](#12-example-autonomous-workflows)
13. [Security Considerations](#13-security-considerations)

---

## 1. Approval Modes & YOLO Mode

By default, Gemini CLI asks for confirmation before running tools. To maximize
autonomy, use approval modes:

### Available Modes

| Mode | Flag | Behavior |
|:-----|:-----|:---------|
| `default` | _(none)_ | Prompts for every tool call |
| `auto_edit` | `--approval-mode auto_edit` | Auto-approves file edits, prompts for shell commands |
| `yolo` | `--yolo` or `--approval-mode yolo` | Auto-approves **everything** |
| `plan` | `--approval-mode plan` | Read-only, requires plan approval before execution |

### Launch in YOLO Mode

```bash
gemini --yolo
# or
gemini --approval-mode yolo
```

### Set as Default (settings.json)

```json
{
  "general": {
    "defaultApprovalMode": "auto_edit"
  }
}
```

> **Note:** `yolo` mode automatically enables Docker sandboxing for safety.
> Use `auto_edit` as a daily-driver balance of speed and safety.

### Keyboard Shortcut

During a session, press **Ctrl+Y** to toggle YOLO mode on/off.

---

## 2. Policy Engine for Fine-Grained Auto-Approval

Instead of blanket YOLO, create targeted policies that auto-approve safe
operations while blocking dangerous ones.

### Create Policy File

```bash
mkdir -p ~/.gemini/policies
```

### `~/.gemini/policies/autonomous.toml`

```toml
# Auto-approve all read operations
[[rule]]
toolName = "read_file"
decision = "allow"
priority = 100

[[rule]]
toolName = "glob"
decision = "allow"
priority = 100

[[rule]]
toolName = "grep_search"
decision = "allow"
priority = 100

[[rule]]
toolName = "ls"
decision = "allow"
priority = 100

[[rule]]
toolName = "web_search"
decision = "allow"
priority = 100

[[rule]]
toolName = "web_fetch"
decision = "allow"
priority = 100

# Auto-approve file edits (write + edit)
[[rule]]
toolName = "write_file"
decision = "allow"
priority = 100

[[rule]]
toolName = "edit"
decision = "allow"
priority = 100

# Auto-approve safe shell commands
[[rule]]
toolName = "run_shell_command"
commandPrefix = "npm test"
decision = "allow"
priority = 200

[[rule]]
toolName = "run_shell_command"
commandPrefix = "npm run build"
decision = "allow"
priority = 200

[[rule]]
toolName = "run_shell_command"
commandPrefix = "npm run lint"
decision = "allow"
priority = 200

[[rule]]
toolName = "run_shell_command"
commandPrefix = "git "
decision = "allow"
priority = 200

[[rule]]
toolName = "run_shell_command"
commandPrefix = "npx "
decision = "allow"
priority = 200

# Auto-approve all MCP tools from trusted servers
[[rule]]
toolName = "mcp_jira_*"
decision = "allow"
priority = 150

# Block dangerous operations
[[rule]]
toolName = "run_shell_command"
commandPrefix = "rm -rf /"
decision = "deny"
priority = 999

[[rule]]
toolName = "run_shell_command"
commandPrefix = "sudo "
decision = "deny"
priority = 999
```

---

## 3. MCP Servers: Extend Capabilities

MCP servers are the **primary extensibility mechanism** for connecting Gemini CLI
to external systems autonomously.

### Essential MCP Servers for Autonomy

Add to `~/.gemini/settings.json`:

```json
{
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-atlassian"],
      "env": {
        "ATLASSIAN_SITE_URL": "$JIRA_SITE_URL",
        "ATLASSIAN_USER_EMAIL": "$JIRA_USER_EMAIL",
        "ATLASSIAN_API_TOKEN": "$JIRA_API_TOKEN"
      },
      "trust": true
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "$GITHUB_TOKEN"
      },
      "trust": true
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/project"],
      "trust": true
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "$DATABASE_URL"
      }
    },
    "slack": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "$SLACK_BOT_TOKEN"
      }
    }
  }
}
```

### Verify MCP Connections

```
/mcp
```

### Use MCP Resources in Prompts

```
@jira://issue/PROJ-456
```

---

## 4. Browser Agent: Autonomous Web Validation

The browser agent can navigate websites, fill forms, click buttons, and take
screenshots — perfect for validating frontend fixes.

### Enable in `~/.gemini/settings.json`

```json
{
  "agents": {
    "overrides": {
      "browser_agent": {
        "enabled": true
      }
    },
    "browser": {
      "sessionMode": "persistent",
      "headless": false
    }
  }
}
```

### Session Modes

| Mode | Use Case |
|:-----|:---------|
| `persistent` | Default. Preserves cookies/state between sessions. Good for logged-in workflows. |
| `isolated` | Clean-state each time. Good for reproducible testing. |
| `existing` | Attach to an already-running Chrome. Good for debugging. |

### Headless Mode for CI/Automation

```json
{
  "agents": {
    "browser": {
      "headless": true,
      "sessionMode": "isolated"
    }
  }
}
```

### Visual Agent (for visual element identification)

```json
{
  "agents": {
    "browser": {
      "visualModel": "gemini-2.5-computer-use-preview-10-2025"
    }
  }
}
```

### Example Usage

```
Use the browser agent to go to http://localhost:3000, click the login button,
fill in test@example.com / password123, and verify the dashboard loads.
```

---

## 5. Custom Subagents: Domain Specialists

Create specialized agents that the main agent can delegate to automatically.

### Enable Custom Agents

```json
{
  "experimental": {
    "enableAgents": true
  }
}
```

### Example: Bug Fixer Agent

Create `.gemini/agents/bug-fixer.md`:

```markdown
---
name: bug-fixer
description: >
  Expert at fixing frontend bugs. Use this agent when a Jira bug needs to be
  analyzed, located in the codebase, fixed, tested, and validated. Handles
  React, TypeScript, CSS, and accessibility issues.
kind: local
tools:
  - read_file
  - write_file
  - edit
  - grep_search
  - glob
  - ls
  - run_shell_command
model: gemini-2.5-pro
temperature: 0.1
max_turns: 30
timeout_mins: 10
---

You are an expert frontend bug fixer. When given a bug description:

1. **Analyze**: Understand the root cause from the description
2. **Locate**: Search the codebase for the affected files
3. **Fix**: Apply the minimal, correct fix
4. **Test**: Run the relevant test suite
5. **Verify**: Confirm tests pass

Rules:
- Make minimal changes — do not refactor surrounding code
- Always run tests after fixing
- If tests fail, analyze and fix until they pass
- Report what you changed and why
```

### Example: QA Validator Agent

Create `.gemini/agents/qa-validator.md`:

```markdown
---
name: qa-validator
description: >
  QA validation agent that uses the browser to verify bug fixes on running
  applications. Delegates to the browser agent for web interaction.
kind: local
tools:
  - browser_agent
  - run_shell_command
  - read_file
model: gemini-2.5-pro
max_turns: 15
timeout_mins: 5
---

You are a QA validation agent. Given a bug description and fix:

1. Navigate to the affected page
2. Reproduce the original bug scenario
3. Verify the fix resolves the issue
4. Check for regressions in related functionality
5. Report PASS/FAIL with evidence
```

---

## 6. Hooks: Automated Guardrails

Hooks run automatically at specific points in the agent loop — use them to
inject context, validate actions, and enforce policies without manual
intervention.

### Configure in `settings.json`

```json
{
  "hooks": {
    "BeforeAgent": [
      {
        "command": "cat .gemini/context/project-context.md",
        "description": "Inject project context before every agent turn"
      }
    ],
    "AfterTool": [
      {
        "command": "bash .gemini/hooks/auto-lint.sh",
        "description": "Auto-lint after file writes",
        "toolNames": ["write_file", "edit"]
      }
    ],
    "SessionStart": [
      {
        "command": "bash .gemini/hooks/setup-env.sh",
        "description": "Set up environment on session start"
      }
    ]
  }
}
```

### Example Hook: Auto-Lint After Edits

`.gemini/hooks/auto-lint.sh`:

```bash
#!/bin/bash
# Read the tool result from stdin, run linter on changed files
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.toolCall.args.filePath // empty')
if [ -n "$FILE" ]; then
  npx eslint --fix "$FILE" 2>/dev/null
fi
echo '{}' # Return empty JSON (no modifications)
```

### Example Hook: Block Production Deploys

`.gemini/hooks/block-prod.sh`:

```bash
#!/bin/bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.toolCall.args.command // empty')
if echo "$CMD" | grep -q "deploy.*prod"; then
  echo '{"decision": "block", "reason": "Production deploys require manual approval"}'
  exit 0
fi
echo '{}'
```

---

## 7. Skills: On-Demand Expertise

Skills are self-contained packages of instructions and resources that activate
contextually.

### Built-in Skills

- `code-reviewer` — Automated code review
- `docs-writer` — Documentation generation
- `pr-creator` — Pull request creation
- `github-issue-creator` — Issue creation

### Create Custom Skills

Create `.gemini/skills/jira-workflow/`:

```
.gemini/skills/jira-workflow/
├── instructions.md
└── resources/
    └── jira-workflow-template.md
```

`instructions.md`:

```markdown
---
name: jira-workflow
description: End-to-end Jira bug fix workflow
triggers:
  - "fix jira"
  - "jira bug"
  - "PROJ-"
---

When activated, follow this workflow:
1. Read the Jira issue using the MCP jira tools
2. Analyze the bug description and acceptance criteria
3. Search the codebase for affected components
4. Implement the fix
5. Run tests
6. Use browser agent to validate visually
7. Update the Jira issue status
8. Create a git commit with the issue key
```

### Activate Skills

```
/skills              # List available skills
/skills enable jira-workflow
```

---

## 8. Plan Mode: Safe Planning Before Acting

Plan mode lets Gemini analyze and plan in read-only mode before executing
changes. This is ideal for complex autonomous workflows where you want a
checkpoint.

### Enable

```json
{
  "experimental": {
    "plan": true
  }
}
```

### Usage

```bash
gemini --approval-mode plan
```

Or within a session:

```
/plan    # Enter plan mode
# ... Gemini creates a plan ...
# Approve the plan to begin execution
```

### Autonomous Planning Pattern

1. Start in plan mode
2. Agent reads Jira bug + codebase → creates plan
3. You approve
4. Agent switches to execution mode → fixes bug → runs tests
5. Agent uses browser agent to validate
6. Agent updates Jira

---

## 9. A2A Server: Background Agents

The Agent-to-Agent (A2A) server enables long-running autonomous tasks that
operate independently.

### Start the A2A Server

```bash
cd packages/a2a-server
npm start
```

### Send Tasks via HTTP

```bash
curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Fix all P1 frontend bugs in Jira project WEBUI",
    "approvalMode": "yolo"
  }'
```

### Use Cases

- Long-running batch fixes
- CI/CD pipeline integration
- Scheduled autonomous maintenance
- Parallel agent execution

---

## 10. Non-Interactive / Headless Mode

Run Gemini CLI without an interactive terminal for automation pipelines.

### Single Prompt Execution

```bash
gemini -p "Fix the bug described in PROJ-456 and run tests" --yolo
```

### Piped Input

```bash
echo "Refactor the AuthService class to use dependency injection" | gemini --yolo
```

### JSON Output (for CI integration)

```bash
gemini -p "Run all tests and report results" --yolo --output json
```

### In Scripts

```bash
#!/bin/bash
JIRA_KEY=$1
gemini -p "
  1. Read Jira issue $JIRA_KEY via MCP
  2. Fix the bug described
  3. Run tests
  4. If tests pass, commit with message 'fix($JIRA_KEY): [description]'
  5. Push to branch fix/$JIRA_KEY
" --yolo
```

---

## 11. Full Autonomous Configuration

Here is a complete `~/.gemini/settings.json` that maximizes autonomy:

```json
{
  "general": {
    "defaultApprovalMode": "auto_edit",
    "devtools": true
  },
  "experimental": {
    "plan": true,
    "enableAgents": true,
    "modelSteering": true,
    "extensionReloading": true
  },
  "agents": {
    "overrides": {
      "browser_agent": {
        "enabled": true
      }
    },
    "browser": {
      "sessionMode": "persistent",
      "headless": false
    }
  },
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-atlassian"],
      "env": {
        "ATLASSIAN_SITE_URL": "$JIRA_SITE_URL",
        "ATLASSIAN_USER_EMAIL": "$JIRA_USER_EMAIL",
        "ATLASSIAN_API_TOKEN": "$JIRA_API_TOKEN"
      },
      "trust": true
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "$GITHUB_TOKEN"
      },
      "trust": true
    }
  }
}
```

### Required Environment Variables

```bash
# Jira
export JIRA_SITE_URL="https://yourcompany.atlassian.net"
export JIRA_USER_EMAIL="you@company.com"
export JIRA_API_TOKEN="your-token"

# GitHub
export GITHUB_TOKEN="ghp_your-token"

# Gemini
export GEMINI_API_KEY="your-gemini-api-key"
```

### Auto-Approval Policies

Create `~/.gemini/policies/full-auto.toml`:

```toml
# Trust all read tools
[[rule]]
toolName = "read_file"
decision = "allow"
priority = 100

[[rule]]
toolName = "glob"
decision = "allow"
priority = 100

[[rule]]
toolName = "grep_search"
decision = "allow"
priority = 100

[[rule]]
toolName = "ls"
decision = "allow"
priority = 100

[[rule]]
toolName = "web_search"
decision = "allow"
priority = 100

[[rule]]
toolName = "web_fetch"
decision = "allow"
priority = 100

# Trust edit tools
[[rule]]
toolName = "write_file"
decision = "allow"
priority = 100

[[rule]]
toolName = "edit"
decision = "allow"
priority = 100

# Trust safe shell commands
[[rule]]
toolName = "run_shell_command"
commandPrefix = "npm "
decision = "allow"
priority = 200

[[rule]]
toolName = "run_shell_command"
commandPrefix = "npx "
decision = "allow"
priority = 200

[[rule]]
toolName = "run_shell_command"
commandPrefix = "git "
decision = "allow"
priority = 200

[[rule]]
toolName = "run_shell_command"
commandPrefix = "node "
decision = "allow"
priority = 200

# Trust all MCP tools from configured servers
[[rule]]
toolName = "mcp_jira_*"
decision = "allow"
priority = 150

[[rule]]
toolName = "mcp_github_*"
decision = "allow"
priority = 150

# Block destructive operations
[[rule]]
toolName = "run_shell_command"
commandPrefix = "rm -rf /"
decision = "deny"
priority = 999

[[rule]]
toolName = "run_shell_command"
commandPrefix = "sudo rm"
decision = "deny"
priority = 999

[[rule]]
toolName = "run_shell_command"
commandPrefix = ":(){ :|:& };:"
decision = "deny"
priority = 999
```

---

## 12. Example Autonomous Workflows

### Workflow 1: Jira Bug → Fix → Validate → Close

```
Read Jira issue FE-123. Fix the bug it describes, run tests, use the browser
agent to validate the fix at http://localhost:3000, then transition the issue
to Done with a comment explaining the fix.
```

### Workflow 2: Batch Fix All P1 Bugs

```bash
gemini -p "
Search Jira for: type = Bug AND priority = Highest AND status = 'To Do'
AND project = WEBUI. For each bug:
1. Read the full issue
2. Fix it
3. Run tests
4. Commit with message 'fix(ISSUE_KEY): description'
Create a summary report when done.
" --yolo
```

### Workflow 3: PR Review + Fix + Validate

```
Review PR #456 on GitHub. For each issue found:
1. Fix the code
2. Run tests
3. Use browser agent to validate if it's a UI change
4. Push the fixes
5. Comment on the PR with what was fixed
```

### Workflow 4: Automated Nightly Maintenance

```bash
#!/bin/bash
# cron: 0 2 * * * /path/to/nightly-maintenance.sh

gemini -p "
1. Search Jira for bugs assigned to me that are in 'To Do' status
2. For each bug, analyze difficulty (simple/medium/complex)
3. Fix all simple bugs
4. Run full test suite
5. Create a PR for each fix
6. Generate a summary report at ./reports/nightly-$(date +%F).md
" --yolo --sandbox
```

---

## 13. Security Considerations

### The Autonomy-Safety Spectrum

| Level | Mode | Trust | Use Case |
|:------|:-----|:------|:---------|
| 1 - Max Safety | `default` approval | No MCP trust | Production code, sensitive repos |
| 2 - Balanced | `auto_edit` + policies | Selective trust | Daily development |
| 3 - High Autonomy | `yolo` + sandbox | Trusted MCP | Personal projects, prototyping |
| 4 - Full Auto | `yolo` + trusted MCP + headless | Full trust | CI/CD, testing environments |

### Best Practices

1. **Always use sandboxing with YOLO mode** — Docker sandbox is auto-enabled
2. **Use policy engine over blanket YOLO** — fine-grained > all-or-nothing
3. **Never trust MCP servers you don't control** — set `"trust": false`
4. **Use environment variables for secrets** — never hardcode tokens
5. **Review hook outputs** — hooks run synchronously and can block the agent
6. **Set `max_turns` on custom agents** — prevent infinite loops
7. **Use `isolated` browser mode for testing** — prevents state leakage
8. **Monitor with devtools** — press F12 during sessions for debug console

### Loop Detection

Gemini CLI has built-in loop detection that prevents the agent from getting
stuck:

- **Tool call loop**: Detects 5 consecutive identical tool calls
- **Content loop**: Detects 10 iterations of repeated content
- **LLM-based check**: After 30 turns, uses a secondary model to evaluate
  whether the agent is making progress

This is active in all modes including YOLO, providing a safety net for
autonomous operation.

---

## Summary: Autonomy Checklist

- [ ] Set approval mode (`auto_edit` or `yolo`)
- [ ] Create policy file in `~/.gemini/policies/`
- [ ] Configure Jira MCP server in `settings.json`
- [ ] Configure GitHub MCP server in `settings.json`
- [ ] Enable browser agent with desired session mode
- [ ] Enable custom agents (`experimental.enableAgents`)
- [ ] Create domain-specific subagents in `.gemini/agents/`
- [ ] Create skills in `.gemini/skills/` for common workflows
- [ ] Set up hooks for auto-linting and safety checks
- [ ] Enable plan mode for complex multi-step tasks
- [ ] Set environment variables for all API tokens
- [ ] Test the full pipeline end-to-end
- [ ] Enable sandboxing for YOLO mode safety
