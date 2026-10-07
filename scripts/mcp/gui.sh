#!/bin/bash
set -euo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
if (( $# > 2 )); then
  echo "Usage: $0 [loopback-address [control-token-file]]" >&2
  exit 2
fi
mcp_address=${1:-${PHOTOCRAFT_MCP_GUI_ADDRESS:-127.0.0.1:7878}}
mcp_token_file=${2:-${PHOTOCRAFT_MCP_TOKEN_FILE:-$mcp_repo_dir/temp/mcp/control.token}}
mcp_start_script=${PHOTOCRAFT_MCP_GUI_START_SCRIPT:-}
# Reuse the verified virtual-display bootstrap in the prepared cloud checkout.
if [[ $mcp_repo_dir == /workspace/photocraft ]]; then
  if [[ $# -lt 2 && -z ${PHOTOCRAFT_MCP_TOKEN_FILE:-} ]]; then
    mcp_token_file=/workspace/photocraft-runtime/control.token
  fi
  if [[ $mcp_address == 127.0.0.1:7878 && -z $mcp_start_script && -f /workspace/photocraft-mcp/ensure-gui.sh ]]; then
    mcp_start_script=/workspace/photocraft-mcp/ensure-gui.sh
  fi
fi
if [[ -n $mcp_start_script ]]; then
  # Children must not retain the startup lock after the bootstrap returns.
  (
    flock -w 20 -x 9 || { echo "PhotoCraft GUI startup lock timed out" >&2; exit 1; }
    bash "$mcp_start_script" 9>&- >&2
  ) 9>"${TMPDIR:-/tmp}/photocraft-gui-start.lock"
fi
if [[ ! -f $mcp_token_file ]]; then
  echo "PhotoCraft control token file not found; start the app with --control <port> --control-token-file $mcp_token_file (see docs/local-mcp.md)." >&2
  exit 1
fi
exec "$mcp_cli" mcp --bridge "$mcp_address" --control-token-file "$mcp_token_file"
