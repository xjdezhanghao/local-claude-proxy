# local-claude-proxy

让 Claude Code 等只支持 Anthropic API 的工具使用本地或局域网部署的大模型，无需官方 Anthropic API Key 及改动模型名称。

## 解决的问题

Claude Code 启动时会在本地校验模型名是否合法，本地或局域网部署的模型（如 vllm-ascend 上的 `ds`）不在白名单里，会被直接拦截报错。

本代理做两件事：

1. 伪造 `/v1/models` 响应，让 Claude Code 本地校验通过
2. 把所有请求中的模型名替换成实际部署的名字

```
Claude Code / Hermes
        ↓  Anthropic 格式请求
  local-claude-proxy (localhost:4000)
  · 伪造 /v1/models 通过本地校验
  · 替换请求体中的模型名
        ↓  透传
  vllm-ascend / 其他本地服务 (局域网)
  · 支持 /v1/messages Anthropic 格式
```

## 前提条件

- WSL2 + [uv](https://github.com/astral-sh/uv)
- 局域网内模型服务支持 `/v1/messages` Anthropic 格式

先确认模型服务可用：

```bash
# 查询模型 id（记下来，后面配置要用）
curl http://192.168.x.x:33333/v1/models

# 确认支持 Anthropic 格式，有正常响应才能继续
curl http://192.168.x.x:33333/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-anything" \
  -d '{
    "model": "你的模型id",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "hello"}]
  }'
```

## 快速安装

```bash
git clone https://github.com/your-username/local-claude-proxy.git
cd local-claude-proxy
bash install.sh http://192.168.x.x:33333 ds
```

`install.sh` 自动完成：依赖安装、配置写入、`~/.bashrc` 自动启动配置。

完成后重新打开终端，或执行：

```bash
source ~/.bashrc
```

## 手动安装

**1. 安装依赖**

```bash
cd ~/local-claude-proxy
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
```

**2. 修改配置**

编辑 `proxy.py` 开头的两个变量：

```python
TARGET = "http://192.168.x.x:33333"   # 模型服务地址
MODEL_NAME = "ds"                       # 模型实际 id
```

**3. 配置 Claude Code**

编辑 `~/.claude/settings.json`（保留已有配置如 `theme`）：

```json
{
  "theme": "dark",
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000",
    "ANTHROPIC_API_KEY": "sk-local"
  }
}
```

> **重要**：必须写在 `settings.json` 里，不能只用 `~/.bashrc` 环境变量——Hermes 通过 systemd 启动，读不到 shell 环境变量。

**4. 启动**

```bash
~/local-claude-proxy/scripts/start.sh
```

**5. 验证**

```bash
# 模型列表
curl http://localhost:4000/v1/models -H "Authorization: Bearer sk-local"

# 请求转发
curl http://localhost:4000/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-local" \
  -d '{
    "model": "ds",
    "max_tokens": 50,
    "messages": [{"role": "user", "content": "hello"}]
  }'

# Claude Code
claude "你好"
```

## 启停

```bash
~/local-claude-proxy/scripts/start.sh   # 启动
~/local-claude-proxyy/scripts/stop.sh    # 停止
```

## 常见问题

| 现象 | 排查步骤 |
|------|---------|
| `ConnectionRefused` | `ps aux \| grep proxy.py` 确认代理在运行 |
| `model does not exist` | `echo $ANTHROPIC_BASE_URL` 确认指向 `localhost:4000`，而非模型服务地址 |
| Hermes 提示未登录 | 检查 `~/.claude/settings.json` 里 `env` 字段是否存在 |
| Hermes `systemd not available` | `/etc/wsl.conf` 改为 `systemd=true`，`wsl --shutdown` 重启 |
| WSL 重启后代理失效 | 新开终端自动启动；或手动执行 `start.sh` |

## License

MIT © [xjdezhanghao](https://github.com/xjdezhanghao)