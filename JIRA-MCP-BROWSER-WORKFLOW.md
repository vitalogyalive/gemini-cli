# Jira + MCP + Browser Agent: End-to-End Bug Fix Workflow

This document describes how to use Gemini CLI to autonomously read a frontend
bug from Jira, fix it, validate it with the browser agent, and document the
results — all from your terminal.

---

## Architecture Overview

```
                          ┌─── PowerShell (Windows Host) ───────────────────────┐
                          │                                                     │
┌─────────────┐  MCP      │  ┌──────────────────┐                              │
│  Gemini CLI  │◄─────────┼─►│  Jira MCP Server │                              │
│  (Agent)     │           │  │  (stdio/http)     │                              │
└──────┬───────┘           │  └──────────────────┘                              │
       │                   │                                                     │
       │  delegates task   │  ┌─────────────────────┐                           │
       ▼                   │  │  Chrome (v144+)     │                           │
┌──────────────┐  CDP/MCP  │  │  + DevTools MCP     │                           │
│ Browser Agent│◄──────────┼─►│  (runs on Windows)  │                           │
│ (subagent)   │           │  └─────────────────────┘                           │
└──────────────┘           │                                                     │
                          └─────────────────────────────────────────────────────┘
                                          │
                                          │ Docker TCP (tcp://localhost:2375)
                                          ▼
                          ┌─── WSL2 (Linux) ────────────────────────────────────┐
                          │                                                     │
                          │  ┌──────────────────────┐                           │
                          │  │  Docker Engine        │                           │
                          │  │  ├── WireMock         │ :8081 (mock API)         │
                          │  │  ├── Frontend App     │ :3000 (dev server)       │
                          │  │  └── PostgreSQL       │ :5432                    │
                          │  └──────────────────────┘                           │
                          │                                                     │
                          └─────────────────────────────────────────────────────┘
```

### Platform Split: PowerShell vs WSL2

| Component | Runs On | Why |
|:----------|:--------|:----|
| **Gemini CLI** | PowerShell (Windows) | Browser agent requires native Chrome access |
| **Browser Agent + Chrome** | PowerShell (Windows) | Chrome must run natively on Windows, not in WSL2 |
| **Docker Engine** | WSL2 (Linux) | Docker Desktop uses WSL2 backend |
| **WireMock** | Docker in WSL2 | Mock APIs for frontend dev/testing |
| **Frontend App** | Docker in WSL2 | Dev server (React, Angular, Vue) |
| **PostgreSQL** | Docker in WSL2 | Local database |

> **Key constraint:** The browser agent launches Chrome via `chrome-devtools-mcp`.
> Chrome must run **natively on Windows** — it cannot run inside WSL2 (no display
> server). Therefore Gemini CLI and the browser agent **must run from PowerShell**.

---

## Step 1: Connect Gemini CLI to Jira via MCP

Gemini CLI has **full MCP (Model Context Protocol) support**. Jira does not ship
a built-in MCP server, so you connect via one of these approaches:

### Option A: Use `@anthropic/mcp-server-atlassian` (Recommended)

The Atlassian MCP server provides read/write access to Jira issues, projects,
and boards.

#### Install

```bash
npm install -g @anthropic/mcp-server-atlassian
```

#### Configure in `~/.gemini/settings.json`

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
      "trust": false
    }
  }
}
```

#### Set environment variables

```bash
export JIRA_SITE_URL="https://yourcompany.atlassian.net"
export JIRA_USER_EMAIL="you@company.com"
export JIRA_API_TOKEN="your-jira-api-token"  # Generate at https://id.atlassian.com/manage-profile/security/api-tokens
```

### Option B: Use a Generic REST MCP Server

If the Atlassian MCP server doesn't exist or doesn't fit, use a generic HTTP/
REST MCP server and point it at the Jira REST API:

```json
{
  "mcpServers": {
    "jira-rest": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-fetch"],
      "env": {
        "BASE_URL": "$JIRA_SITE_URL",
        "AUTH_HEADER": "Basic $JIRA_BASE64_AUTH"
      }
    }
  }
}
```

### Option C: Build a Custom Jira MCP Server

Create a lightweight MCP server in TypeScript:

```typescript
// jira-mcp-server.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "jira", version: "1.0.0" });

server.registerTool(
  "get_issue",
  {
    description: "Fetch a Jira issue by key (e.g. PROJ-123)",
    inputSchema: { key: z.string().describe("Jira issue key") },
  },
  async ({ key }) => {
    const resp = await fetch(
      `${process.env.JIRA_URL}/rest/api/3/issue/${key}`,
      {
        headers: {
          Authorization: `Basic ${Buffer.from(
            `${process.env.JIRA_EMAIL}:${process.env.JIRA_TOKEN}`
          ).toString("base64")}`,
          Accept: "application/json",
        },
      }
    );
    const issue = await resp.json();
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              key: issue.key,
              summary: issue.fields.summary,
              description: issue.fields.description,
              status: issue.fields.status.name,
              priority: issue.fields.priority.name,
              type: issue.fields.issuetype.name,
              labels: issue.fields.labels,
              assignee: issue.fields.assignee?.displayName,
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

server.registerTool(
  "search_issues",
  {
    description: "Search Jira issues with JQL",
    inputSchema: {
      jql: z.string().describe("JQL query string"),
      maxResults: z.number().optional().describe("Max results (default 10)"),
    },
  },
  async ({ jql, maxResults = 10 }) => {
    const resp = await fetch(
      `${process.env.JIRA_URL}/rest/api/3/search?jql=${encodeURIComponent(
        jql
      )}&maxResults=${maxResults}`,
      {
        headers: {
          Authorization: `Basic ${Buffer.from(
            `${process.env.JIRA_EMAIL}:${process.env.JIRA_TOKEN}`
          ).toString("base64")}`,
          Accept: "application/json",
        },
      }
    );
    const data = await resp.json();
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            data.issues.map((i: any) => ({
              key: i.key,
              summary: i.fields.summary,
              status: i.fields.status.name,
              type: i.fields.issuetype.name,
            })),
            null,
            2
          ),
        },
      ],
    };
  }
);

server.registerTool(
  "transition_issue",
  {
    description: "Transition a Jira issue to a new status",
    inputSchema: {
      key: z.string(),
      transitionId: z.string(),
      comment: z.string().optional(),
    },
  },
  async ({ key, transitionId, comment }) => {
    const body: any = { transition: { id: transitionId } };
    if (comment) {
      body.update = {
        comment: [
          {
            add: {
              body: {
                type: "doc",
                version: 1,
                content: [
                  {
                    type: "paragraph",
                    content: [{ type: "text", text: comment }],
                  },
                ],
              },
            },
          },
        ],
      };
    }
    await fetch(
      `${process.env.JIRA_URL}/rest/api/3/issue/${key}/transitions`,
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${Buffer.from(
            `${process.env.JIRA_EMAIL}:${process.env.JIRA_TOKEN}`
          ).toString("base64")}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      }
    );
    return {
      content: [{ type: "text", text: `Issue ${key} transitioned.` }],
    };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

Register it:

```json
{
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["tsx", "./mcp-servers/jira-mcp-server.ts"],
      "env": {
        "JIRA_URL": "$JIRA_SITE_URL",
        "JIRA_EMAIL": "$JIRA_USER_EMAIL",
        "JIRA_TOKEN": "$JIRA_API_TOKEN"
      }
    }
  }
}
```

### Verify Connection

After starting Gemini CLI:

```
/mcp
```

You should see `jira (CONNECTED)` with its tools listed.

---

## Step 2: Read a Frontend Bug from Jira

Once connected, ask Gemini CLI to fetch the bug:

```
Read the Jira issue PROJ-456 and analyze the frontend bug described in it
```

Or search for frontend bugs:

```
Search Jira for open frontend bugs: type = Bug AND labels = frontend AND status = "To Do"
```

Gemini will call the MCP tools (`mcp_jira_get_issue` or `mcp_jira_search_issues`)
and present the bug details in your terminal.

---

## Step 3: Fix the Bug

Gemini CLI has full access to your local codebase. After reading the bug, ask:

```
Now fix this bug in our codebase. The issue describes [X happening when Y].
Look at the relevant frontend components and apply the fix.
```

Gemini will:
1. Use `grep_search` / `read_file` to locate the affected code
2. Use `edit` / `write_file` to apply the fix
3. Optionally run tests with `run_shell_command`

---

## Step 4: Launch Browser Agent to Validate

### Enable the Browser Agent

Add to your `~/.gemini/settings.json`:

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

### Prerequisites

- Chrome v144+ installed **on Windows** (not in WSL2)
- Node.js with `npx` available **in PowerShell**
- Gemini CLI running **from PowerShell** (not from WSL2 terminal)
- Docker exposed on TCP from WSL2 (see below)

### Docker via WSL2 over TCP

The frontend app and WireMock run in Docker containers inside WSL2. To let
Gemini CLI (running in PowerShell) interact with them:

#### 1. Expose Docker daemon on TCP in WSL2

In WSL2, edit `/etc/docker/daemon.json`:

```json
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"]
}
```

Restart Docker in WSL2:

```bash
sudo systemctl restart docker
```

#### 2. Set DOCKER_HOST in PowerShell

```powershell
$env:DOCKER_HOST = "tcp://localhost:2375"
```

Or persist in your PowerShell profile (`$PROFILE`):

```powershell
[System.Environment]::SetEnvironmentVariable("DOCKER_HOST", "tcp://localhost:2375", "User")
```

#### 3. Run WireMock for Frontend Mocking

WireMock provides mock API endpoints so the frontend can run independently of
the real backend:

```bash
# In WSL2
docker run -d --name wiremock \
  -p 8081:8080 \
  -v $(pwd)/wiremock/mappings:/home/wiremock/mappings \
  -v $(pwd)/wiremock/__files:/home/wiremock/__files \
  wiremock/wiremock:latest

# Verify from PowerShell
curl http://localhost:8081/__admin/mappings
```

#### 4. Run Frontend Dev Server in Docker

```bash
# In WSL2
docker compose up -d frontend
# Frontend available at http://localhost:3000 from both WSL2 and Windows
```

#### 5. Verify Cross-Platform Connectivity

From PowerShell:

```powershell
# Docker commands work via TCP
docker ps

# Frontend reachable from Windows (browser agent will use this)
curl http://localhost:3000

# WireMock reachable from Windows
curl http://localhost:8081/__admin
```

### Validate the Fix

```
Use the browser agent to navigate to http://localhost:3000 and verify that
the bug PROJ-456 is fixed. The bug was about [description]. Confirm that:
1. The page loads without errors
2. The specific interaction works correctly
3. Take a screenshot showing the fixed state
```

The browser agent will:
- Launch Chrome via `chrome-devtools-mcp`
- Navigate to the target URL
- Interact with the page using accessibility tree UIDs
- Use `analyze_screenshot` for visual validation
- Report back pass/fail with evidence

---

## Step 5: Update Jira and Create Report

```
Transition PROJ-456 to "In Review" and add a comment describing the fix.
Then create a markdown report of everything we did.
```

---

## Example: Complete Session Transcript

```powershell
# Launch from PowerShell — NOT from WSL2 terminal
PS C:\project> gemini

> Read Jira issue FE-789
# Agent calls mcp_jira_get_issue("FE-789")
# Returns: "Button click handler on checkout page fires twice causing
#           duplicate orders. Affects CheckoutButton component."

> Fix this bug in our codebase
# Agent reads src/components/CheckoutButton.tsx
# Finds: onClick handler missing event.preventDefault() and debounce
# Applies fix with edit tool
# Runs: npm test -- --testPathPattern=CheckoutButton

> Use the browser agent to verify the fix at http://localhost:3000/checkout
# Browser agent launches Chrome
# Navigates to checkout page
# Clicks the checkout button
# Verifies only one order is created
# Reports: "PASS - Single order confirmed"

> Transition FE-789 to Done with a comment about the fix
# Agent calls mcp_jira_transition_issue("FE-789", "31", "Fixed duplicate
#   click in CheckoutButton by adding debounce and preventDefault")
```

---

## Configuration Checklist

| Component | Required | Runs On | How |
|:----------|:---------|:--------|:----|
| Gemini CLI | Yes | **PowerShell** | `npm i -g @anthropic-ai/gemini-cli` |
| Jira MCP Server | Yes | **PowerShell** | `settings.json` → `mcpServers.jira` |
| Jira API Token | Yes | **PowerShell** | Environment variable `JIRA_API_TOKEN` |
| Browser Agent | Yes | **PowerShell** | `settings.json` → `agents.overrides.browser_agent.enabled: true` |
| Chrome v144+ | Yes | **Windows** | Install from google.com/chrome (native, not WSL2) |
| Node.js + npx | Yes | **PowerShell** | Already required for Gemini CLI |
| Docker Engine | Yes | **WSL2** | Docker Desktop with WSL2 backend |
| Docker TCP | Yes | **WSL2→Windows** | Expose daemon on `tcp://0.0.0.0:2375` |
| WireMock | Yes | **Docker/WSL2** | `docker run wiremock/wiremock` on port 8081 |
| Frontend Dev Server | Yes | **Docker/WSL2** | `docker compose up frontend` on port 3000 |
| `DOCKER_HOST` env | Yes | **PowerShell** | `$env:DOCKER_HOST = "tcp://localhost:2375"` |
| Plan Mode | Recommended | **PowerShell** | `settings.json` → `experimental.plan: true` |
| Custom Agents | Optional | **PowerShell** | `settings.json` → `experimental.enableAgents: true` |

---

## Security Notes

- **Never hardcode API tokens** in `settings.json`. Use `$ENV_VAR` references.
- Set `"trust": false` for the Jira MCP server so tool calls require confirmation.
- The browser agent blocks `file://`, `javascript:`, and sensitive Chrome URLs.
- Sensitive actions (form fills, submissions) require user confirmation.
- Gemini CLI automatically redacts sensitive env vars from MCP server processes.
