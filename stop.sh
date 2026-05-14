#!/bin/bash
# 停止 local-claude-proxy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$(dirname "$SCRIPT_DIR")/proxy.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "local-claude-proxy is not running (no PID file found)"
    exit 1
fi

PID=$(cat "$PID_FILE")

if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    rm "$PID_FILE"
    echo "local-claude-proxy stopped (PID=$PID)"
else
    echo "Process $PID not found, cleaning up PID file"
    rm "$PID_FILE"
fi
