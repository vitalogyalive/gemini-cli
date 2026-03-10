# Autonomous Backend Workflow: Spring Boot + GCP with Gemini CLI

End-to-end autonomous workflow for fixing bugs and implementing evolutions in a
Spring Boot backend deployed on Google Cloud Platform — from Jira ticket to
validated production-ready code.

---

## Architecture Overview

```
┌─── PowerShell (Windows Host) ──────────────────────────────────────────────────┐
│                                                                                │
│  ┌──────────────┐  MCP    ┌───────────────┐   MCP    ┌────────────────────┐   │
│  │  Gemini CLI  │◄───────►│  Jira Server  │          │  GCP MCP Server    │   │
│  │  (Orchestr.) │         └───────────────┘   ┌─────►│  (Cloud Run, GKE,  │   │
│  │              │◄────────────────────────────►┘      │   Logging, SQL)    │   │
│  │              │  MCP    ┌───────────────┐           └────────────────────┘   │
│  │              │◄───────►│  PostgreSQL   │                                    │
│  │              │         │  (via proxy)  │   ┌────────────────────┐           │
│  │              │         └───────────────┘   │  Browser Agent     │           │
│  │              │◄───────────────────────────►│  (Chrome on Win)   │           │
│  └──────┬───────┘                             │  → Swagger UI      │           │
│         │                                     └────────────────────┘           │
│         │  reads/writes                                                        │
│         ▼                                                                      │
│  ┌─────────────────────────────────────┐                                       │
│  │  Spring Boot Project (local)        │                                       │
│  │  ├── src/main/java/...              │                                       │
│  │  ├── src/test/java/...              │                                       │
│  │  ├── build.gradle / pom.xml         │                                       │
│  │  ├── application.yml                │                                       │
│  │  └── docker-compose.yml             │                                       │
│  └─────────────────────────────────────┘                                       │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
                              │
                              │ Docker TCP (tcp://localhost:2375)
                              ▼
┌─── WSL2 (Linux) ──────────────────────────────────────────────────────────────┐
│                                                                                │
│  ┌─────────────────────────────────────────────────┐                           │
│  │  Docker Engine                                   │                           │
│  │  ├── WireMock           :8081 (mock APIs)        │                           │
│  │  ├── PostgreSQL         :5432 (local DB)         │                           │
│  │  ├── Redis / Kafka      :6379 / :9092 (optional) │                           │
│  │  └── Spring Boot (alt.) :8080 (containerized)    │                           │
│  └─────────────────────────────────────────────────┘                           │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

### Platform Split: PowerShell vs WSL2

| Component | Runs On | Why |
|:----------|:--------|:----|
| **Gemini CLI** | PowerShell (Windows) | Browser agent requires native Chrome |
| **Browser Agent + Chrome** | PowerShell (Windows) | Chrome must run natively — no display server in WSL2 |
| **Spring Boot (dev)** | PowerShell (Windows) | `./gradlew bootRun` with live reload |
| **Docker Engine** | WSL2 (Linux) | Docker Desktop uses WSL2 backend |
| **WireMock** | Docker in WSL2 | Mock backend APIs for integration testing |
| **PostgreSQL** | Docker in WSL2 | Local database for development |
| **Redis / Kafka** | Docker in WSL2 | Optional infrastructure services |
| **gcloud CLI** | PowerShell (Windows) | GCP operations from the host |

> **Key constraint:** The browser agent launches Chrome via `chrome-devtools-mcp`.
> Chrome cannot run inside WSL2 (no display server). Gemini CLI and the browser
> agent **must run from PowerShell on Windows**.

---

## Table of Contents

1. [MCP Server Configuration](#1-mcp-server-configuration)
2. [Custom Subagents for Spring Boot](#2-custom-subagents-for-spring-boot)
3. [Workflow: Bug Fix](#3-workflow-bug-fix)
4. [Workflow: Feature Evolution](#4-workflow-feature-evolution)
5. [GCP Integration](#5-gcp-integration)
6. [Automated Testing & Validation](#6-automated-testing--validation)
7. [Browser Agent for API Validation](#7-browser-agent-for-api-validation)
8. [Hooks for Spring Boot Projects](#8-hooks-for-spring-boot-projects)
9. [Skills for Backend Workflows](#9-skills-for-backend-workflows)
10. [Full settings.json Configuration](#10-full-settingsjson-configuration)
11. [Non-Interactive CI/CD Pipeline](#11-non-interactive-cicd-pipeline)
12. [Example Sessions](#12-example-sessions)

---

## 1. MCP Server Configuration

### `~/.gemini/settings.json`

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

    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "$DATABASE_URL"
      },
      "trust": false
    },

    "gcp": {
      "command": "npx",
      "args": ["-y", "tsx", ".gemini/mcp-servers/gcp-mcp-server.ts"],
      "env": {
        "GCP_PROJECT_ID": "$GCP_PROJECT_ID",
        "GOOGLE_APPLICATION_CREDENTIALS": "$GOOGLE_APPLICATION_CREDENTIALS"
      },
      "trust": false
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

### Environment Variables

```bash
# Jira
export JIRA_SITE_URL="https://yourcompany.atlassian.net"
export JIRA_USER_EMAIL="you@company.com"
export JIRA_API_TOKEN="your-jira-api-token"

# Database (local or Cloud SQL via proxy)
export DATABASE_URL="postgresql://user:pass@localhost:5432/myapp"

# GCP
export GCP_PROJECT_ID="my-project-id"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"

# GitHub
export GITHUB_TOKEN="ghp_xxx"

# Gemini
export GEMINI_API_KEY="your-gemini-api-key"
```

### Custom GCP MCP Server

Create `.gemini/mcp-servers/gcp-mcp-server.ts`:

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);
const server = new McpServer({ name: "gcp", version: "1.0.0" });
const project = process.env.GCP_PROJECT_ID;

// Read Cloud Run service logs
server.registerTool(
  "cloud_run_logs",
  {
    description: "Fetch recent logs from a Cloud Run service",
    inputSchema: {
      service: z.string().describe("Cloud Run service name"),
      limit: z.number().optional().describe("Number of log entries (default 50)"),
      severity: z
        .enum(["DEFAULT", "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"])
        .optional(),
      since: z.string().optional().describe("Time filter e.g. '1h', '30m', '2d'"),
    },
  },
  async ({ service, limit = 50, severity, since }) => {
    let cmd = `gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=${service}`;
    if (severity) cmd += ` AND severity>=${severity}`;
    if (since) cmd += ` AND timestamp>=\"$(date -u -d '${since} ago' +%Y-%m-%dT%H:%M:%SZ)\"`;
    cmd += `" --project=${project} --limit=${limit} --format=json`;
    const { stdout } = await execAsync(cmd);
    return { content: [{ type: "text", text: stdout }] };
  }
);

// List Cloud Run services
server.registerTool(
  "cloud_run_list",
  {
    description: "List all Cloud Run services in the project",
    inputSchema: {},
  },
  async () => {
    const { stdout } = await execAsync(
      `gcloud run services list --project=${project} --format=json`
    );
    return { content: [{ type: "text", text: stdout }] };
  }
);

// Deploy to Cloud Run
server.registerTool(
  "cloud_run_deploy",
  {
    description: "Deploy a container image to Cloud Run",
    inputSchema: {
      service: z.string(),
      image: z.string().describe("Container image URI"),
      region: z.string().default("europe-west1"),
      envVars: z.record(z.string()).optional(),
    },
  },
  async ({ service, image, region, envVars }) => {
    let cmd = `gcloud run deploy ${service} --image=${image} --region=${region} --project=${project} --quiet`;
    if (envVars) {
      const vars = Object.entries(envVars)
        .map(([k, v]) => `${k}=${v}`)
        .join(",");
      cmd += ` --set-env-vars="${vars}"`;
    }
    const { stdout } = await execAsync(cmd);
    return { content: [{ type: "text", text: stdout }] };
  }
);

// Query Cloud SQL (via proxy)
server.registerTool(
  "cloud_sql_query",
  {
    description: "Run a read-only SQL query against Cloud SQL (via local proxy)",
    inputSchema: {
      query: z.string().describe("SQL SELECT query"),
      database: z.string().optional().describe("Database name"),
    },
  },
  async ({ query, database }) => {
    if (!query.trim().toUpperCase().startsWith("SELECT")) {
      return {
        content: [{ type: "text", text: "ERROR: Only SELECT queries allowed" }],
      };
    }
    const db = database || "myapp";
    const { stdout } = await execAsync(
      `psql "${process.env.DATABASE_URL}/${db}" -c "${query}" --csv`
    );
    return { content: [{ type: "text", text: stdout }] };
  }
);

// GKE pod logs
server.registerTool(
  "gke_pod_logs",
  {
    description: "Fetch logs from a GKE pod by label selector",
    inputSchema: {
      namespace: z.string().default("default"),
      selector: z.string().describe("Label selector e.g. app=my-service"),
      tail: z.number().default(100),
    },
  },
  async ({ namespace, selector, tail }) => {
    const { stdout } = await execAsync(
      `kubectl logs -n ${namespace} -l ${selector} --tail=${tail} --timestamps`
    );
    return { content: [{ type: "text", text: stdout }] };
  }
);

// Cloud Monitoring metrics
server.registerTool(
  "cloud_monitoring",
  {
    description: "Read a Cloud Monitoring metric for a resource",
    inputSchema: {
      metric: z.string().describe("Metric type e.g. run.googleapis.com/request_latencies"),
      resource: z.string().describe("Resource label filter"),
      minutes: z.number().default(60),
    },
  },
  async ({ metric, resource, minutes }) => {
    const end = new Date().toISOString();
    const start = new Date(Date.now() - minutes * 60000).toISOString();
    const { stdout } = await execAsync(
      `gcloud monitoring time-series list --project=${project} ` +
        `--filter="metric.type=\"${metric}\" AND ${resource}" ` +
        `--interval-start-time=${start} --interval-end-time=${end} --format=json`
    );
    return { content: [{ type: "text", text: stdout }] };
  }
);

// Pub/Sub publish (for testing event-driven services)
server.registerTool(
  "pubsub_publish",
  {
    description: "Publish a message to a Pub/Sub topic (for testing)",
    inputSchema: {
      topic: z.string(),
      message: z.string().describe("JSON message body"),
      attributes: z.record(z.string()).optional(),
    },
  },
  async ({ topic, message, attributes }) => {
    let cmd = `gcloud pubsub topics publish ${topic} --project=${project} --message='${message}'`;
    if (attributes) {
      const attrs = Object.entries(attributes)
        .map(([k, v]) => `${k}=${v}`)
        .join(",");
      cmd += ` --attribute="${attrs}"`;
    }
    const { stdout } = await execAsync(cmd);
    return { content: [{ type: "text", text: stdout }] };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

---

## 2. Custom Subagents for Spring Boot

### Bug Fixer Agent

Create `.gemini/agents/spring-boot-fixer.md`:

```markdown
---
name: spring-boot-fixer
description: >
  Expert Spring Boot backend bug fixer. Use for any Java/Kotlin Spring Boot bug
  involving REST controllers, services, repositories, JPA entities, security
  config, or GCP integrations. Handles Maven and Gradle projects.
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
max_turns: 40
timeout_mins: 15
---

You are an expert Spring Boot backend developer. When given a bug:

## Analysis Phase
1. Read the bug description carefully — extract error messages, stack traces,
   affected endpoints, and reproduction steps
2. Identify the bug category:
   - **NullPointerException** → Check null safety, Optional usage, bean injection
   - **HTTP 4xx/5xx** → Check controller mappings, validation, exception handlers
   - **JPA/Hibernate** → Check entity mappings, lazy loading, transactions
   - **Security** → Check SecurityFilterChain, CORS, JWT/OAuth config
   - **GCP Integration** → Check credentials, IAM, client library config
   - **Serialization** → Check Jackson config, DTOs, circular references
   - **Performance** → Check N+1 queries, missing indexes, connection pools

## Location Phase
3. Search for the affected code:
   - Controllers: `src/main/java/**/controller/**`
   - Services: `src/main/java/**/service/**`
   - Repositories: `src/main/java/**/repository/**`
   - Entities: `src/main/java/**/model/**` or `**/entity/**`
   - Config: `src/main/java/**/config/**`
   - Properties: `src/main/resources/application*.yml` or `*.properties`
4. Read the full class and its imports to understand dependencies

## Fix Phase
5. Apply the minimal correct fix:
   - Prefer fixing the root cause over adding workarounds
   - Keep Spring conventions (constructor injection, @Transactional on service)
   - Use proper HTTP status codes in exception handlers
   - Respect existing code style (indentation, naming, import ordering)

## Validation Phase
6. Run tests:
   - `./gradlew test` or `./mvnw test`
   - If specific test exists: `./gradlew test --tests "ClassName.methodName"`
7. If tests fail, read the failure output and fix until green
8. Run the application briefly to verify startup:
   - `./gradlew bootRun &` then `curl http://localhost:8080/actuator/health`
   - Kill the process after verification

## Rules
- NEVER change test expectations to match buggy behavior
- ALWAYS check for related tests before and after fixing
- If no test covers the bug, create one
- Use `@Transactional(readOnly = true)` for read operations
- Prefer `Optional` over null checks for repository returns
- Use `@Valid` and Bean Validation for input validation
```

### Evolution Agent

Create `.gemini/agents/spring-boot-evolver.md`:

```markdown
---
name: spring-boot-evolver
description: >
  Spring Boot feature evolution agent. Use for implementing new endpoints,
  adding service layer logic, creating entities, database migrations,
  integrating GCP services (Pub/Sub, Cloud Storage, Cloud SQL), and
  evolving existing APIs.
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
temperature: 0.2
max_turns: 50
timeout_mins: 20
---

You are a senior Spring Boot architect implementing feature evolutions.

## Planning Phase
1. Understand the feature requirements from the Jira ticket
2. Map the feature to Spring Boot layers:
   - **Controller** → New/modified endpoints
   - **Service** → Business logic
   - **Repository** → Data access
   - **Entity/DTO** → Data models
   - **Config** → New beans, security rules, properties
   - **Migration** → Flyway/Liquibase scripts

## Architecture Phase
3. Analyze existing patterns in the codebase:
   - How are endpoints structured? (REST resource naming)
   - Is there a base controller or common response wrapper?
   - What validation strategy is used? (Bean Validation, custom)
   - How are exceptions handled? (ControllerAdvice, custom)
   - What's the DTO strategy? (Records, Lombok, MapStruct)

## Implementation Phase — follow this order:
4. **Database migration** (if needed):
   - Flyway: `src/main/resources/db/migration/V{next}__description.sql`
   - Liquibase: `src/main/resources/db/changelog/changes/`
5. **Entity** (if new table/columns):
   - JPA annotations, proper relationships, cascading
   - Use `@CreatedDate`, `@LastModifiedDate` if auditing exists
6. **Repository**:
   - Spring Data JPA interface
   - Custom queries with `@Query` if needed
   - Projections for read-only operations
7. **DTO / Request / Response objects**:
   - Use Java Records where possible
   - Bean Validation annotations (`@NotNull`, `@Size`, `@Email`)
   - MapStruct mapper if the project uses it
8. **Service**:
   - `@Service` with constructor injection
   - `@Transactional` for write operations
   - Proper exception types (custom or Spring's)
9. **Controller**:
   - RESTful endpoint naming
   - `@Valid` on request bodies
   - Proper HTTP status codes (201 for creation, 204 for deletion)
   - OpenAPI annotations if `springdoc-openapi` is present
10. **Tests**:
    - Unit tests for service layer (Mockito)
    - Integration tests for controller (`@WebMvcTest` or `@SpringBootTest`)
    - Repository tests if custom queries (`@DataJpaTest`)

## GCP-Specific Patterns
- **Cloud Storage**: Use `spring-cloud-gcp-starter-storage`
- **Pub/Sub**: Use `spring-cloud-gcp-starter-pubsub`
- **Cloud SQL**: Connection via `spring-cloud-gcp-starter-sql-postgresql`
- **Secret Manager**: `spring-cloud-gcp-starter-secretmanager`
- **Cloud Tasks**: REST client with `WebClient`

## Validation Phase
11. Run full test suite: `./gradlew test`
12. Run linter: `./gradlew spotlessCheck` or `./gradlew checkstyleMain`
13. Build: `./gradlew build`
14. If project has integration tests: `./gradlew integrationTest`

## Rules
- Follow existing project conventions exactly
- Never skip writing tests for new code
- Use `@Profile` for environment-specific beans
- Document new endpoints if OpenAPI is configured
- Add new properties to `application.yml` with sensible defaults
- Keep backward compatibility — don't break existing endpoints
```

### GCP Ops Agent

Create `.gemini/agents/gcp-ops.md`:

```markdown
---
name: gcp-ops
description: >
  GCP operations agent for Cloud Run, GKE, Cloud SQL, Pub/Sub, and Cloud
  Logging. Use for checking logs, monitoring metrics, debugging deployment
  issues, and managing cloud resources.
kind: local
tools:
  - run_shell_command
  - read_file
  - web_fetch
model: gemini-2.5-pro
temperature: 0.1
max_turns: 20
timeout_mins: 10
---

You are a GCP operations expert. You can:

1. **Read Cloud Logging** — fetch and analyze service logs
2. **Check Cloud Run** — list services, read revisions, check health
3. **Query Cloud SQL** — read-only queries via local proxy
4. **Monitor** — read Cloud Monitoring metrics, check error rates
5. **Debug** — correlate logs, traces, and metrics to find root causes

Commands you can use (via run_shell_command):
- `gcloud logging read ...`
- `gcloud run services describe ...`
- `gcloud run revisions list ...`
- `gcloud sql instances describe ...`
- `kubectl logs ...` (if GKE)
- `curl` for health checks and API testing

Rules:
- NEVER modify production resources without explicit confirmation
- NEVER run DELETE or destructive gcloud commands
- Only use SELECT queries against databases
- Always include `--project` flag in gcloud commands
- Prefer `--format=json` for parseable output
```

---

## 3. Workflow: Bug Fix

### The Full Autonomous Bug Fix Loop

```
┌─────────────────┐
│  1. READ JIRA   │ ──► Fetch bug ticket, extract stack trace,
│     TICKET      │     affected endpoint, reproduction steps
└────────┬────────┘
         ▼
┌─────────────────┐
│  2. CHECK GCP   │ ──► Read Cloud Run/GKE logs for the error,
│     LOGS        │     correlate timestamps, find root cause hints
└────────┬────────┘
         ▼
┌─────────────────┐
│  3. LOCATE      │ ──► Search codebase for affected controller,
│     CODE        │     service, repository, entity
└────────┬────────┘
         ▼
┌─────────────────┐
│  4. FIX CODE    │ ──► Apply minimal fix, respect conventions,
│                 │     add/update test coverage
└────────┬────────┘
         ▼
┌─────────────────┐
│  5. RUN TESTS   │ ──► ./gradlew test (or mvnw test)
│                 │     Fix until green
└────────┬────────┘
         ▼
┌─────────────────┐
│  6. VALIDATE    │ ──► Browser agent → Swagger UI → hit endpoint
│     VIA API     │     OR curl the running app
└────────┬────────┘
         ▼
┌─────────────────┐
│  7. COMMIT &    │ ──► git commit -m "fix(PROJ-123): description"
│     UPDATE JIRA │     Transition issue → In Review
└─────────────────┘
```

### Example Prompt

```
Read Jira issue BACKEND-789. Check the Cloud Run logs for the "order-service"
for related errors. Fix the bug in the codebase, run tests, validate the fix
by calling the affected endpoint via curl, then commit and update the Jira
issue to "In Review".
```

### What Gemini CLI Does Autonomously

1. **Calls** `mcp_jira_get_issue("BACKEND-789")` → gets bug description
2. **Calls** `mcp_gcp_cloud_run_logs("order-service", severity="ERROR")` → gets stack trace
3. **Reads** `src/main/java/.../OrderController.java` → finds affected code
4. **Edits** the file with the fix
5. **Runs** `./gradlew test --tests "OrderControllerTest"` → verifies
6. **Runs** `./gradlew bootRun` in background, then `curl http://localhost:8080/api/orders/test`
7. **Commits** with conventional commit message
8. **Calls** `mcp_jira_transition_issue("BACKEND-789", "In Review")`

---

## 4. Workflow: Feature Evolution

### The Full Autonomous Evolution Loop

```
┌─────────────────┐
│  1. READ JIRA   │ ──► Fetch feature ticket, extract acceptance
│     STORY       │     criteria, API contract, data model needs
└────────┬────────┘
         ▼
┌─────────────────┐
│  2. ANALYZE     │ ──► Understand existing patterns: controller
│     CODEBASE    │     structure, DTO strategy, test conventions
└────────┬────────┘
         ▼
┌─────────────────┐
│  3. PLAN (opt)  │ ──► Enter plan mode, design the implementation,
│                 │     get user approval before coding
└────────┬────────┘
         ▼
┌─────────────────┐
│  4. IMPLEMENT   │ ──► Migration → Entity → Repository → DTO →
│     (layered)   │     Service → Controller → Tests
└────────┬────────┘
         ▼
┌─────────────────┐
│  5. TEST        │ ──► Unit + Integration + Build
│                 │     Fix until all green
└────────┬────────┘
         ▼
┌─────────────────┐
│  6. VALIDATE    │ ──► Browser agent → Swagger UI → test all
│     ENDPOINTS   │     new endpoints, verify responses
└────────┬────────┘
         ▼
┌─────────────────┐
│  7. COMMIT &    │ ──► git commit -m "feat(PROJ-456): description"
│     CREATE PR   │     Push branch, create PR, update Jira
└─────────────────┘
```

### Example Prompt

```
Read Jira story BACKEND-456. It describes a new "Payment History" endpoint.
Implement it following the existing patterns in the codebase:
1. Create the entity and Flyway migration
2. Create the repository with custom query
3. Create request/response DTOs
4. Implement the service with proper transactions
5. Add the REST endpoint with validation
6. Write unit and integration tests
7. Run all tests and build
8. Use the browser agent to test via Swagger UI at http://localhost:8080/swagger-ui.html
9. Commit and create a PR
```

---

## 5. GCP Integration

### Cloud Run Debugging Pattern

```
Check Cloud Run service "payment-service" in project "my-project":
1. List recent revisions
2. Read ERROR and WARNING logs from the last 2 hours
3. Check request latency metrics
4. Identify the root cause of the 500 errors
```

### Cloud SQL Investigation

```
The "user-service" is returning stale data. Investigate:
1. Check the Cloud SQL connection pool settings in application.yml
2. Query the database directly to verify data state
3. Check for missing cache invalidation
4. Review the JPA entity for caching annotations
```

### Pub/Sub Event-Driven Debugging

```
Messages published to "order-events" topic are not being processed.
1. Check the subscriber logs in Cloud Run
2. Verify the subscription configuration
3. Publish a test message and trace its processing
4. Check for deserialization errors in the consumer
```

### Common GCP + Spring Boot Issues

| Symptom | Common Cause | Agent Action |
|:--------|:-------------|:-------------|
| 500 on startup | Missing env vars / secrets | Check `application.yml` + Cloud Run env config |
| Connection refused to DB | Cloud SQL proxy not running | Check `spring.datasource.url` + proxy status |
| Pub/Sub messages not received | Wrong subscription or ACK deadline | Check `@PubSubListener` config |
| Slow cold starts | Large dependency tree | Check startup metrics, consider GraalVM native |
| Auth failures | IAM roles / service account | Check `GOOGLE_APPLICATION_CREDENTIALS` |
| OOM kills | Heap too large for container | Check `-Xmx` in `JAVA_TOOL_OPTIONS` |

---

## 6. Automated Testing & Validation

### Policy: Auto-Approve Build & Test Commands

Add to `~/.gemini/policies/spring-boot.toml`:

```toml
# Gradle
[[rule]]
toolName = "run_shell_command"
commandPrefix = "./gradlew "
decision = "allow"
priority = 200

# Maven
[[rule]]
toolName = "run_shell_command"
commandPrefix = "./mvnw "
decision = "allow"
priority = 200

# Docker Compose (runs via TCP to WSL2)
[[rule]]
toolName = "run_shell_command"
commandPrefix = "docker compose "
decision = "allow"
priority = 200

# Docker commands (WireMock, PostgreSQL, etc. in WSL2)
[[rule]]
toolName = "run_shell_command"
commandPrefix = "docker ps"
decision = "allow"
priority = 200

[[rule]]
toolName = "run_shell_command"
commandPrefix = "docker logs"
decision = "allow"
priority = 200

[[rule]]
toolName = "run_shell_command"
commandPrefix = "docker exec"
decision = "allow"
priority = 200

# WireMock admin API
[[rule]]
toolName = "run_shell_command"
commandPrefix = "curl http://localhost:8081"
decision = "allow"
priority = 200

# curl for API testing
[[rule]]
toolName = "run_shell_command"
commandPrefix = "curl "
decision = "allow"
priority = 200

# gcloud read-only
[[rule]]
toolName = "run_shell_command"
commandPrefix = "gcloud logging read"
decision = "allow"
priority = 200

[[rule]]
toolName = "run_shell_command"
commandPrefix = "gcloud run services list"
decision = "allow"
priority = 200

[[rule]]
toolName = "run_shell_command"
commandPrefix = "gcloud run services describe"
decision = "allow"
priority = 200

# Block production deploys
[[rule]]
toolName = "run_shell_command"
commandPrefix = "gcloud run deploy"
decision = "deny"
priority = 999

[[rule]]
toolName = "run_shell_command"
commandPrefix = "kubectl delete"
decision = "deny"
priority = 999
```

### Test Execution Patterns

```bash
# Gradle - run all tests
./gradlew test

# Gradle - specific test class
./gradlew test --tests "com.example.service.OrderServiceTest"

# Gradle - specific test method
./gradlew test --tests "com.example.service.OrderServiceTest.shouldCalculateTotal"

# Gradle - integration tests (if separated)
./gradlew integrationTest

# Maven equivalents
./mvnw test
./mvnw test -Dtest="OrderServiceTest"
./mvnw test -Dtest="OrderServiceTest#shouldCalculateTotal"
./mvnw verify  # includes integration tests

# Build + check
./gradlew build        # compiles + tests + checks
./gradlew spotlessCheck  # code formatting
./gradlew checkstyleMain # style violations
```

---

## 7. Browser Agent for API Validation

The browser agent can validate backend APIs through Swagger UI or any web
interface. It **must run from PowerShell on Windows** — Chrome cannot run
inside WSL2.

### Prerequisites

- Gemini CLI running **from PowerShell** (not WSL2 terminal)
- Chrome v144+ installed **on Windows**
- Docker exposed via TCP from WSL2 (for WireMock and dependencies)

### Enable Browser Agent

```json
{
  "agents": {
    "overrides": {
      "browser_agent": { "enabled": true }
    },
    "browser": {
      "sessionMode": "isolated",
      "headless": false
    }
  }
}
```

### Docker via WSL2 over TCP

Backend dependencies (WireMock, PostgreSQL, Redis, Kafka) run in Docker inside
WSL2. To let Gemini CLI control them from PowerShell:

#### 1. Expose Docker daemon on TCP in WSL2

Edit `/etc/docker/daemon.json` in WSL2:

```json
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"]
}
```

Restart Docker:

```bash
sudo systemctl restart docker
```

#### 2. Set DOCKER_HOST in PowerShell

```powershell
$env:DOCKER_HOST = "tcp://localhost:2375"
```

Persist in your profile:

```powershell
# Add to $PROFILE
[System.Environment]::SetEnvironmentVariable("DOCKER_HOST", "tcp://localhost:2375", "User")
```

#### 3. Run WireMock for API Mocking

WireMock mocks external APIs or microservices that the Spring Boot app depends
on — useful for integration testing without real services:

```bash
# In WSL2
docker run -d --name wiremock \
  -p 8081:8080 \
  -v $(pwd)/wiremock/mappings:/home/wiremock/mappings \
  -v $(pwd)/wiremock/__files:/home/wiremock/__files \
  wiremock/wiremock:latest
```

Example WireMock mapping (`wiremock/mappings/payment-gateway.json`):

```json
{
  "request": {
    "method": "POST",
    "urlPattern": "/api/v1/payments/charge"
  },
  "response": {
    "status": 200,
    "headers": { "Content-Type": "application/json" },
    "jsonBody": {
      "transactionId": "TXN-MOCK-001",
      "status": "APPROVED",
      "amount": 99.99
    }
  }
}
```

Configure Spring Boot to point to WireMock in `application-local.yml`:

```yaml
external-services:
  payment-gateway:
    base-url: http://localhost:8081/api/v1/payments
```

#### 4. Run Full Stack with Docker Compose

```yaml
# docker-compose.yml (runs in WSL2)
services:
  postgres:
    image: postgres:16
    ports: ["5432:5432"]
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass

  wiremock:
    image: wiremock/wiremock:latest
    ports: ["8081:8080"]
    volumes:
      - ./wiremock/mappings:/home/wiremock/mappings
      - ./wiremock/__files:/home/wiremock/__files

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
```

```bash
# In WSL2
docker compose up -d

# Verify from PowerShell
docker ps                           # via TCP
curl http://localhost:8081/__admin   # WireMock
curl http://localhost:5432           # PostgreSQL (will get protocol error = OK)
```

#### 5. Run Spring Boot on Windows, Deps on WSL2

```powershell
# PowerShell — Spring Boot connects to Docker services via localhost
$env:SPRING_PROFILES_ACTIVE = "local"
./gradlew bootRun

# Services are reachable:
# - PostgreSQL:  localhost:5432  (Docker/WSL2)
# - WireMock:    localhost:8081  (Docker/WSL2)
# - Spring Boot: localhost:8080  (Windows native)
# - Chrome:      launched by browser agent (Windows native)
```

### Validate via Swagger UI

```
Use the browser agent to:
1. Navigate to http://localhost:8080/swagger-ui.html
2. Find the "Payment" API section
3. Expand POST /api/payments
4. Click "Try it out"
5. Fill the request body with: {"amount": 99.99, "currency": "EUR", "orderId": "ORD-001"}
6. Click "Execute"
7. Verify the response is 201 Created with a payment ID
8. Then test GET /api/payments/{id} with the returned ID
9. Verify it returns the payment details
```

### Validate via curl (Alternative — No Browser Needed)

For pure API validation, the agent can use shell commands directly:

```
Validate the fix by running these curl commands:
1. POST /api/orders with a test payload, expect 201
2. GET /api/orders/{id} with the returned ID, expect 200
3. PUT /api/orders/{id} with updated data, expect 200
4. DELETE /api/orders/{id}, expect 204
5. GET /api/orders/{id} again, expect 404
```

### Validate Actuator Health

```
Start the application and check:
1. GET /actuator/health → expect {"status": "UP"}
2. GET /actuator/info → expect version and build info
3. GET /actuator/metrics/http.server.requests → check for error rates
```

---

## 8. Hooks for Spring Boot Projects

### Auto-Format After Edits

`settings.json`:

```json
{
  "hooks": {
    "AfterTool": [
      {
        "command": "bash .gemini/hooks/auto-format-java.sh",
        "description": "Auto-format Java files after edit",
        "toolNames": ["write_file", "edit"]
      }
    ],
    "BeforeAgent": [
      {
        "command": "bash .gemini/hooks/inject-spring-context.sh",
        "description": "Inject Spring Boot project context"
      }
    ]
  }
}
```

### `.gemini/hooks/auto-format-java.sh`

```bash
#!/bin/bash
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.toolCall.args.filePath // .toolCall.args.file_path // empty')

if [[ "$FILE" == *.java ]] || [[ "$FILE" == *.kt ]]; then
  if [ -f "./gradlew" ]; then
    ./gradlew spotlessApply -q 2>/dev/null || true
  elif [ -f "./mvnw" ]; then
    ./mvnw spotless:apply -q 2>/dev/null || true
  fi
fi

echo '{}'
```

### `.gemini/hooks/inject-spring-context.sh`

```bash
#!/bin/bash
# Inject project structure and key configs into agent context
cat <<'CONTEXT'
{
  "addToContext": [
    {
      "type": "text",
      "text": "Spring Boot project context injected. Key files: application.yml, build.gradle (or pom.xml). Test with ./gradlew test. Start with ./gradlew bootRun."
    }
  ]
}
CONTEXT
```

---

## 9. Skills for Backend Workflows

### Bug Fix Skill

Create `.gemini/skills/spring-bug-fix/instructions.md`:

```markdown
---
name: spring-bug-fix
description: End-to-end Spring Boot bug fix workflow from Jira to validated fix
triggers:
  - "fix spring bug"
  - "fix backend bug"
  - "BACKEND-"
---

When activated, execute this workflow autonomously:

1. **Read** the Jira ticket using MCP jira tools
2. **Extract** from the ticket:
   - Error message / stack trace
   - Affected endpoint or service
   - Reproduction steps
   - Expected vs actual behavior
3. **Check GCP logs** if the bug is in a deployed service
4. **Locate** the affected code in the Spring Boot project
5. **Analyze** the root cause
6. **Fix** the code — minimal change, root cause fix
7. **Add/update tests** to cover the bug scenario
8. **Run** `./gradlew test` (or `./mvnw test`)
9. **Validate** via curl or browser agent
10. **Commit** with message: `fix(ISSUE-KEY): description`
11. **Update Jira** — transition to "In Review", add fix comment
```

### Feature Evolution Skill

Create `.gemini/skills/spring-evolution/instructions.md`:

```markdown
---
name: spring-evolution
description: Implement a Spring Boot feature evolution from Jira story
triggers:
  - "implement feature"
  - "spring evolution"
  - "new endpoint"
---

When activated, follow this layered implementation approach:

1. **Read** the Jira story/feature ticket
2. **Analyze** existing codebase patterns
3. **Plan** the implementation (enter plan mode if complex)
4. **Implement** in order:
   - Database migration (Flyway/Liquibase)
   - JPA Entity
   - Spring Data Repository
   - Request/Response DTOs
   - Service layer with business logic
   - REST Controller with validation
   - Exception handling
   - OpenAPI documentation (if springdoc present)
5. **Test** each layer:
   - `@DataJpaTest` for repository
   - Unit test with Mockito for service
   - `@WebMvcTest` for controller
   - `@SpringBootTest` for integration
6. **Build**: `./gradlew build`
7. **Validate** via Swagger UI or curl
8. **Commit**: `feat(ISSUE-KEY): description`
9. **Create PR** and update Jira
```

---

## 10. Full settings.json Configuration

Complete autonomous Spring Boot + GCP configuration for a **PowerShell + WSL2**
environment:

### PowerShell Environment Setup

Set these in your PowerShell profile (`$PROFILE`) or session:

```powershell
# Docker — route to WSL2 engine via TCP
$env:DOCKER_HOST = "tcp://localhost:2375"

# Spring Boot
$env:SPRING_PROFILES_ACTIVE = "local"

# Jira
$env:JIRA_SITE_URL = "https://yourcompany.atlassian.net"
$env:JIRA_USER_EMAIL = "you@company.com"
$env:JIRA_API_TOKEN = "your-token"

# GitHub
$env:GITHUB_TOKEN = "ghp_xxx"

# Database (PostgreSQL in Docker/WSL2, exposed on localhost)
$env:DATABASE_URL = "postgresql://user:pass@localhost:5432/myapp"

# GCP
$env:GCP_PROJECT_ID = "my-project-id"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"

# Gemini
$env:GEMINI_API_KEY = "your-gemini-api-key"
```

### WSL2 Docker Setup

In WSL2, ensure Docker daemon is exposed on TCP:

```bash
# /etc/docker/daemon.json
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"]
}

# Restart
sudo systemctl restart docker
```

Start infrastructure:

```bash
# In WSL2
docker compose up -d   # postgres, wiremock, redis, etc.
```

### `~/.gemini/settings.json`

```json
{
  "general": {
    "defaultApprovalMode": "auto_edit"
  },
  "experimental": {
    "plan": true,
    "enableAgents": true,
    "modelSteering": true
  },
  "agents": {
    "overrides": {
      "browser_agent": {
        "enabled": true
      }
    },
    "browser": {
      "sessionMode": "isolated",
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
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "$DATABASE_URL"
      },
      "trust": false
    }
  },
  "hooks": {
    "AfterTool": [
      {
        "command": "bash .gemini/hooks/auto-format-java.sh",
        "description": "Auto-format Java/Kotlin after edits",
        "toolNames": ["write_file", "edit"]
      }
    ]
  }
}
```

### Startup Checklist (PowerShell)

```powershell
# 1. Start Docker deps in WSL2 (from PowerShell via TCP)
docker compose up -d

# 2. Verify services
docker ps                                    # WireMock, Postgres, Redis running
curl http://localhost:8081/__admin            # WireMock accessible
curl http://localhost:8080/actuator/health    # (after bootRun)

# 3. Launch Gemini CLI from PowerShell
gemini --approval-mode auto_edit

# 4. Verify MCP connections
> /mcp
# Should show: jira (CONNECTED), github (CONNECTED), postgres (CONNECTED)
```

---

## 11. Non-Interactive CI/CD Pipeline

### Automated Bug Fix in CI

```bash
#!/bin/bash
# ci-autofix.sh — Run from CI to fix a Jira bug autonomously
JIRA_KEY=$1

gemini -p "
Read Jira issue $JIRA_KEY. Fix the bug described in the Spring Boot codebase.
Run tests with ./gradlew test. If tests pass, commit with message
'fix($JIRA_KEY): [brief description]' and push to branch fix/$JIRA_KEY.
Create a PR targeting main. Update Jira to 'In Review'.
" --yolo --sandbox
```

### Automated Test + Validate in CI

```bash
#!/bin/bash
# ci-validate.sh — Validate a fix after merge
SERVICE=$1
gemini -p "
Check Cloud Run logs for '$SERVICE' after the latest deployment.
Look for ERROR or WARNING entries in the last 30 minutes.
If errors found, analyze root cause and create a Jira bug ticket.
If clean, report deployment success.
" --yolo
```

### Nightly Maintenance Script

```bash
#!/bin/bash
# nightly-backend-maintenance.sh
gemini -p "
1. Search Jira: type=Bug AND priority in (Highest,High) AND status='To Do'
   AND project=BACKEND AND labels=auto-fixable
2. For each bug:
   a. Read the issue
   b. Analyze if it's safely auto-fixable (null checks, missing validation, etc.)
   c. If safe: fix it, test it, commit, push, create PR
   d. If complex: add comment 'Needs manual review' and skip
3. Generate report at ./reports/nightly-$(date +%F).md
" --yolo --sandbox
```

---

## 12. Example Sessions

> **All sessions below run from PowerShell on Windows.** Docker deps
> (WireMock, PostgreSQL) are running in WSL2 and reachable on `localhost`
> via TCP.

### Session 1: Fix a NullPointerException

```powershell
PS C:\project> gemini --approval-mode auto_edit

> Read Jira issue BACKEND-101

Agent calls mcp_jira_get_issue("BACKEND-101"):
  Summary: NPE in OrderService when guest user places order
  Stack trace: OrderService.java:45 - user.getAddress().getCity()
  Steps: Place order without logging in

> Fix this bug

Agent reads src/main/java/.../service/OrderService.java
Agent identifies: user.getAddress() can be null for guest users
Agent edits line 45:
  - String city = user.getAddress().getCity();
  + String city = Optional.ofNullable(user.getAddress())
  +     .map(Address::getCity)
  +     .orElse("Unknown");

Agent runs: ./gradlew test --tests "OrderServiceTest"
  ✓ All 12 tests pass

Agent writes new test:
  @Test
  void shouldHandleGuestUserWithoutAddress() { ... }

Agent runs: ./gradlew test
  ✓ All 13 tests pass (1 new)

> Validate the fix

Agent runs: ./gradlew bootRun &
Agent runs: curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"items":[{"sku":"ABC","qty":1}]}'
  → 201 Created ✓

Agent commits: fix(BACKEND-101): handle null address for guest users
Agent transitions Jira to "In Review"
```

### Session 2: Add a New Endpoint

```
> Read Jira story BACKEND-202 and implement it

Agent calls mcp_jira_get_issue("BACKEND-202"):
  Summary: Add payment history endpoint
  AC: GET /api/payments/history?userId={id}&from={date}&to={date}
      Returns paginated list of payments with amount, date, status

> Implement following existing patterns

Agent analyzes codebase:
  - Uses Java Records for DTOs
  - Uses MapStruct for mapping
  - Uses Spring Data JPA Specifications for filtering
  - Uses springdoc-openapi for docs
  - Uses Flyway for migrations

Agent creates:
  1. V15__add_payment_history_index.sql (migration)
  2. PaymentHistoryResponse.java (record DTO)
  3. PaymentRepository.java (adds findByUserIdAndDateBetween)
  4. PaymentService.java (adds getPaymentHistory)
  5. PaymentController.java (adds GET /api/payments/history)
  6. PaymentControllerTest.java (WebMvcTest)
  7. PaymentServiceTest.java (unit test)

Agent runs: ./gradlew test → ✓ All pass
Agent runs: ./gradlew build → ✓ Build successful

> Validate via Swagger UI

Browser agent:
  1. Navigates to http://localhost:8080/swagger-ui.html
  2. Finds "Payment" section
  3. Expands GET /api/payments/history
  4. Clicks "Try it out"
  5. Fills: userId=1, from=2025-01-01, to=2025-12-31
  6. Clicks Execute
  7. Verifies: 200 OK with paginated response ✓

Agent commits: feat(BACKEND-202): add payment history endpoint with filtering
Agent creates PR and updates Jira
```

---

## Quick Reference Card

| Action | Command / Prompt |
|:-------|:-----------------|
| Read Jira bug | `Read Jira issue PROJ-123` |
| Check GCP logs | `Check Cloud Run logs for "service-name" errors in last 1h` |
| Fix a bug | `Fix the bug described in PROJ-123` |
| Run tests | `Run ./gradlew test` |
| Run specific test | `Run ./gradlew test --tests "ClassName"` |
| Start app | `Run ./gradlew bootRun` |
| Validate via curl | `curl -X GET http://localhost:8080/api/endpoint` |
| Validate via browser | `Use browser agent to test via Swagger UI` (PowerShell only) |
| Check DB | `Query the payments table for user 123` |
| Start Docker deps | `docker compose up -d` (via TCP to WSL2) |
| Check WireMock | `curl http://localhost:8081/__admin/mappings` |
| Commit | `Commit with conventional message fix(PROJ-123): desc` |
| Create PR | `Create a PR targeting main` |
| Update Jira | `Transition PROJ-123 to "In Review"` |
| Full autonomous | `gemini --yolo -p "Fix PROJ-123 end to end"` (from PowerShell) |
