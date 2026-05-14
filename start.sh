#!/bin/bash
# 启动 local-claude-proxy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$PROXY_DIR/proxy.pid"
LOG_FILE="$PROXY_DIR/proxy.log"

cd "$PROXY_DIR"
source .venv/bin/activate

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "local-claude-proxy already running (PID=$OLD_PID)"
        exit 0
    else
        rm "$PID_FILE"
    fi
fi

nohup python proxy.py > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
echo "local-claude-proxy started (PID=$(cat $PID_FILE)), log: $LOG_FILE"
