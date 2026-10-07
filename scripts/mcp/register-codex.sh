#!/bin/bash
set -euo pipefail
mcp_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
codex mcp add photocraft -- /bin/bash "$mcp_script_dir/headless.sh"
codex mcp add photocraft_gui -- /bin/bash "$mcp_script_dir/gui.sh"
