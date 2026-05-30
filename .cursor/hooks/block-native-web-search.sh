#!/usr/bin/env bash
# Blocks native WebSearch/WebFetch; agents must use the SearXNG MCP server instead.
# Evidence: .cursor/rules/agent-tool-routing.mdc, .cursor/rules/mcp-servers.mdc

set -euo pipefail
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // .toolName // empty')

case "$tool_name" in
  WebSearch)
    cat <<'EOF'
{
  "permission": "deny",
  "user_message": "Native WebSearch is disabled. Use the SearXNG MCP server (http://localhost:4001).",
  "agent_message": "Use CallMcpTool with server searxng (or project-0-monorepo-searxng) and tool searxng_web_search. Read the tool schema first. Never retry native WebSearch."
}
EOF
    exit 0
    ;;
  WebFetch)
    cat <<'EOF'
{
  "permission": "deny",
  "user_message": "Native WebFetch is disabled. Use SearXNG web_url_read for page content.",
  "agent_message": "Use CallMcpTool with server searxng and tool web_url_read for URLs. Use Context7 (resolve-library-id + query-docs) only for library API documentation. Never retry native WebFetch."
}
EOF
    exit 0
    ;;
esac

echo '{"permission":"allow"}'
exit 0
