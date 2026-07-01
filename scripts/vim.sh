#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

# Compatibility wrapper for the legacy module name; TPM installation now lives in scripts/tpm.sh.
exec bash "$SCRIPT_DIR/tpm.sh" "$@"
