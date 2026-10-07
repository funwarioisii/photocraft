#!/bin/bash
set -euo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
if (( $# > 1 )); then
  echo "Usage: $0 [image-workspace]" >&2
  exit 2
fi
mcp_work_root=${1:-$mcp_work_root}
mkdir -p -- "$mcp_work_root"
mcp_work_root=$(cd -- "$mcp_work_root" && pwd -P)
exec "$mcp_cli" mcp --automation-read-root "$mcp_work_root" --automation-write-root "$mcp_work_root"
