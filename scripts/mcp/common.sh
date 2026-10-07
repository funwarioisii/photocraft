#!/bin/bash
# Shared setup for the local MCP launchers; stdout belongs to JSON-RPC.
set -euo pipefail
mcp_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
mcp_repo_dir=$(cd -- "$mcp_script_dir/../.." && pwd -P)
if [[ -n ${PHOTOCRAFT_MCP_ENV_FILE:-} ]]; then
  . "$PHOTOCRAFT_MCP_ENV_FILE"
elif [[ $mcp_repo_dir == /workspace/photocraft && -f /workspace/photocraft-env.sh ]]; then
  . /workspace/photocraft-env.sh
fi
mcp_target_dir=${CARGO_TARGET_DIR:-$mcp_repo_dir/target}
if [[ $mcp_target_dir != /* ]]; then
  mcp_target_dir=$mcp_repo_dir/$mcp_target_dir
fi
mcp_cli=${PHOTOCRAFT_MCP_CLI:-$mcp_target_dir/debug/photocraft-cli}
if [[ -z ${PHOTOCRAFT_MCP_CLI:-} && ! -x $mcp_cli && -x $mcp_target_dir/release/photocraft-cli ]]; then
  mcp_cli=$mcp_target_dir/release/photocraft-cli
fi
if [[ ! -x $mcp_cli ]]; then
  echo "PhotoCraft CLI not found at $mcp_cli; run cargo build --locked -p photocraft-cli in $mcp_repo_dir or set PHOTOCRAFT_MCP_CLI." >&2
  exit 1
fi
mcp_work_root=${PHOTOCRAFT_MCP_WORKSPACE:-$mcp_repo_dir/temp/mcp/work}
if [[ -z ${PHOTOCRAFT_MCP_WORKSPACE:-} && $mcp_repo_dir == /workspace/photocraft && -d /workspace/photocraft-runtime/work ]]; then
  mcp_work_root=/workspace/photocraft-runtime/work
fi
