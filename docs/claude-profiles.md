# Claude Profiles — 动态 Claude 命令配置

## 概述

Claude Profiles 允许你为 HAPI 配置**多套 Claude Code 启动命令**，每套可以指定不同的二进制路径和环境变量。

**适用场景：**

- 通过第三方 API 代理使用 Claude Code（如阿里云 DashScope、DeepSeek 等）
- 有多个模型后端，需要按需切换
- Claude Code 启动前需要设置特殊环境变量
- 别人提供的 Claude Code 包装脚本，本地需要交互选择模型，远程需要自动跳过交互

## 快速开始

### 1. 配置 Profile

编辑 `~/.hapi/claude-profiles.json`：

```json
{
  "profiles": [
    {
      "name": "default",
      "label": "Default Claude"
    },
    {
      "name": "qwen",
      "label": "Qwen Coder (Aliyun)",
      "command": "/home/qiao/bin/claude-qwen",
      "env": {
        "OPENAI_BASE_URL": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "OPENAI_MODEL": "qwen3-coder-plus"
      }
    },
    {
      "name": "deepseek",
      "label": "DeepSeek V3",
      "command": "/home/qiao/bin/claude-ds",
      "env": {
        "OPENAI_BASE_URL": "https://api.deepseek.com/v1",
        "OPENAI_MODEL": "deepseek-chat"
      }
    }
  ]
}
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `name` | 是 | 唯一标识，命令行传参和 spawn 请求使用 |
| `label` | 是 | 在 Web UI 下拉框中的显示名称 |
| `command` | 否 | Claude 可执行文件路径。不填则走 `HAPI_CLAUDE_PATH` → PATH 回退 |
| `env` | 否 | 启动 Claude 时注入的环境变量 |

### 2. 使用方式

**Web UI（远程创建会话）：**

选择 Claude 作为 Agent 时，表单会出现 `Claude Profile` 下拉框，选择对应的 profile 即可。

**命令行（本机终端）：**

```bash
hapi --profile qwen                          # 指定 profile
hapi --profile deepseek --yolo               # 组合其他选项
hapi --resume --profile qwen                 # 恢复会话时也可以用
```

### 3. 动态生效

`~/.hapi/claude-profiles.json` 在每次启动 Claude 进程时实时读取，**增删改 profile 即时生效，无需重启 HAPI 服务或重新编译**。

---

## 交互式脚本兼容方案

如果 profile 指向的脚本在本地终端需要**交互选择**（如选择模型），但远程模式下没有 TTY 会卡死，可以使用一层薄壳来解决。

### 原理

```
Profile command
  → ~/bin/hapi-claude-entry  （薄壳：判断 TTY）
      ├── 有终端 → 执行原交互脚本（你手动选）
      └── 无终端 → 跳过交互，直接用 profile 里预设的 env 启动 claude
```

### 薄壳脚本示例

```bash
#!/bin/bash
# ~/bin/hapi-claude-entry

ORIGINAL="/别人提供的/交互脚本.sh"   # ← 你无法修改的原脚本

if [ -t 0 ]; then
    # 本机终端 → 正常交互
    exec "$ORIGINAL" "$@"
else
    # 远程模式（无 TTY）→ 跳过交互
    # Profile 里的 env 已经被 HAPI 注入了（OPENAI_BASE_URL, OPENAI_MODEL 等）
    exec claude "$@"
fi
```

```bash
chmod +x ~/bin/hapi-claude-entry
```

然后在 profile 配置中把 `command` 指向这个薄壳即可。

### 效果

| 场景 | 行为 |
|------|------|
| 终端直接 `hapi --profile xxx` | 执行原交互脚本，正常选模型 |
| Web UI / 手机远程创建会话 | 跳过交互，用 profile 预设环境变量 |

原脚本完全不需要修改。

---

## 工作原理

### 优先级

Claude 可执行文件解析优先级：

1. Profile 中的 `command`（最高）
2. `HAPI_CLAUDE_PATH` 环境变量
3. PATH 中的 `claude`

环境变量优先级：

1. Profile 中的 `env`
2. `claudeEnvVars`
3. 系统环境变量

### 数据流（Web UI 创建会话）

```
Web UI 下拉框选 Profile
  → POST /api/machines/:id/spawn { profile: "qwen", ... }
  → Hub RPCGateway
  → Runner buildCliArgs("--profile", "qwen")
  → 新 hapi 进程解析 --profile → 存入 Session
  → claudeLocal() / claudeRemote() 读取 ~/.hapi/claude-profiles.json
  → 解析 profile → 用其 command + env 启动 Claude
```

### API

`GET /api/claude-profiles`

返回当前 hub 机器上配置的所有 profile（仅 `name` + `label`，不暴露 `command` 和 `env`）。

需要 Bearer Token 鉴权。

---

## 管理脚本

项目提供了 `scripts/manage-hapi.sh` 用于管理 HAPI 服务：

```bash
# 启动（hub + runner）
./scripts/manage-hapi.sh start

# 停止
./scripts/manage-hapi.sh stop

# 重启
./scripts/manage-hapi.sh restart

# 查看状态
./scripts/manage-hapi.sh status
```
