#!/bin/bash
# 一键安装 local-claude-proxy
# 用法: bash install.sh <模型服务地址> <模型id>
# 示例: bash install.sh http://192.168.1.100:30001 ds

set -e

PROXY_DIR="$HOME/local-claude-proxy"
TARGET="${1:-http://192.168.x.x:30001}"
MODEL_NAME="${2:-ds}"

echo "=== local-claude-proxy 安装向导 ==="
echo "模型服务地址: $TARGET"
echo "模型 ID:      $MODEL_NAME"
echo ""

# 1. 复制文件
echo "[1/5] 复制文件到 $PROXY_DIR ..."
mkdir -p "$PROXY_DIR/scripts"
cp proxy.py "$PROXY_DIR/proxy.py"
cp scripts/start.sh "$PROXY_DIR/scripts/start.sh"
cp scripts/stop.sh "$PROXY_DIR/scripts/stop.sh"
chmod +x "$PROXY_DIR/scripts/start.sh" "$PROXY_DIR/scripts/stop.sh"

# 2. 写入配置
echo "[2/5] 写入配置..."
sed -i "s|http://192.168.x.x:30001|$TARGET|g" "$PROXY_DIR/proxy.py"
sed -i "s|MODEL_NAME = \"ds\"|MODEL_NAME = \"$MODEL_NAME\"|g" "$PROXY_DIR/proxy.py"

# 3. 安装依赖
echo "[3/5] 安装 Python 依赖..."
cd "$PROXY_DIR"
uv venv
source .venv/bin/activate
uv pip install fastapi uvicorn httpx

# 4. 配置 ~/.claude/settings.json
echo "[4/5] 配置 ~/.claude/settings.json ..."
mkdir -p ~/.claude
SETTINGS="$HOME/.claude/settings.json"

if [ -f "$SETTINGS" ]; then
    python3 - << PYEOF
import json
with open("$SETTINGS") as f:
    cfg = json.load(f)
cfg.setdefault("env", {})
cfg["env"]["ANTHROPIC_BASE_URL"] = "http://localhost:4000"
cfg["env"]["ANTHROPIC_API_KEY"] = "sk-local"
with open("$SETTINGS", "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("  已合并到现有 settings.json")
PYEOF
else
    cat > "$SETTINGS" << 'JSON'
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000",
    "ANTHROPIC_API_KEY": "sk-local"
  }
}
JSON
    echo "  已创建 settings.json"
fi

# 5. 配置 ~/.bashrc 自动启动
echo "[5/5] 配置 ~/.bashrc 自动启动..."
MARKER="# local-claude-proxy auto-start"
if grep -q "$MARKER" ~/.bashrc; then
    echo "  ~/.bashrc 已有自动启动配置，跳过"
else
    cat >> ~/.bashrc << BASHEOF

$MARKER
if [ -f ~/local-claude-proxy/proxy.pid ]; then
    OLD_PID=\$(cat ~/local-claude-proxy/proxy.pid)
    if ! kill -0 "\$OLD_PID" 2>/dev/null; then
        rm ~/local-claude-proxy/proxy.pid
        ~/local-claude-proxy/scripts/start.sh > /dev/null 2>&1
    fi
else
    ~/local-claude-proxy/scripts/start.sh > /dev/null 2>&1
fi
BASHEOF
    echo "  已写入 ~/.bashrc"
fi

echo ""
echo "=== 安装完成 ==="
echo ""
echo "启动代理:"
echo "  ~/local-claude-proxy/scripts/start.sh"
echo ""
echo "验证:"
echo "  curl http://localhost:4000/v1/models -H 'Authorization: Bearer sk-local'"
echo ""
echo "请重新打开终端或执行: source ~/.bashrc"
