# Local MCP integration

UniContext implements MCP `2025-11-25` over stdio. The client starts the executable as a child
process and sends one compact JSON-RPC object per line. Standard output is reserved for MCP
messages; diagnostics go to standard error.

The server also accepts protocol revisions `2025-06-18` and `2024-11-05`. It exposes an empty
prompt list because historical clients may request `prompts/list` even when they do not consume
MCP prompts.

Reference specifications:

- <https://modelcontextprotocol.io/specification/2025-11-25/basic/transports>
- <https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle>
- <https://modelcontextprotocol.io/specification/2025-11-25/server/tools>

## Generic declaration

Clients that accept command-based MCP servers can adapt this entry:

```json
{
  "mcpServers": {
    "unicontext": {
      "command": "/absolute/path/to/unicontext",
      "args": ["serve", "--manifest", "/absolute/path/to/unicontext.toml"]
    }
  }
}
```

The exact file shape and location depend on the client. Verify the current local schema before
copying this declaration into Maki, Crush, Claude Code, or Codex.

## Locally verified matrix

| Client | Version | Result | Observation |
| --- | --- | --- | --- |
| Crush | 0.76.0 | Passed | Discovered and called `memory_get` with `m4-local`. |
| Maki | 0.4.11 | Passed | Discovered and called `unicontext__memory_get` in `--print` mode with `llamacpp/m4-local`. |
| Maki | 0.2.9 | MCP passed, agent not validated | Direct protocol negotiation passed, but `--print` started before asynchronous tool publication. Its TUI could not be automated reliably in a PTY. |
| Claude Code | 2.1.236 | Passed | Isolated configuration health check reported `Connected`. |
| Codex CLI | 0.149.0 | Passed | Command-line configuration override listed UniContext as `enabled`. |

These tests use temporary project configurations and do not modify global client configuration.
Maki `0.2.9` expects `.maki/config.toml`; Maki `0.4.11` uses `.maki/mcp.toml`.

## Lifecycle

1. Rebuild the index with `unicontext index --manifest …`.
2. Start the server with `unicontext serve --manifest …`.
3. Negotiate `initialize`, then send `notifications/initialized`.
4. Discover tools through `tools/list`.
5. Pass the active worktree as `repository` when live Git context is required.
6. Preserve returned identifiers and paths in every synthesis.

## Security

The manifest fixes the allowed roots and two append-only write areas. A note cannot declare a
visibility wider than its root. `memory_propose` writes only to the inbox, and `session_*` writes
only new session events. Existing targets cause an error. The server has no network, shell, or
canonical-memory write capability.

The optional repository inspection is also read-only. It executes only `git rev-parse`,
`git branch --show-current`, `git status --short`, `git diff --cached`, and
`git diff --no-ext-diff` with direct process arguments. Status, staged diff, and unstaged diff
share the same bounded context budget.
