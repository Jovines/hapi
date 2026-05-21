# Claude Profiles — 动态 Claude 命令配置

## 这是什么

HAPI 默认调用系统 PATH 里的 `claude` 命令。如果你需要通过**第三方的 Claude Code 包装脚本**来启动 Claude（比如阿里云百炼、DeepSeek 代理、或者其他你需要特殊环境变量才能运行的 Claude），Profile 功能可以让你：

- 定义**多套**不同的 Claude 启动命令和环境变量
- 在 Web 界面创建会话时**下拉选择**要用的配置
- 本地终端通过 `hapi --profile <名字>` 直接指定
- 配置文件**随时修改即时生效**，无需重启或重编译
- 即使包装脚本需要**交互选择**（比如选模型），也能通过薄壳兼容远程无终端场景

---

## 第一步：构建并部署

```bash
# 1. 克隆仓库
git clone https://github.com/Jovines/hapi.git
cd hapi
git checkout feat/claude-profile-selector

# 2. 安装依赖
bun install

# 3. 构建（包含前端 + Hub + CLI 全部）
bun run build:single-exe

# 4. 挂载到全局（bun link 方式，不影响 npm 包）
cd cli && bun link

# 5. 把构建好的二进制补到平台包里（bun link 会解析到项目本地的旧二进制）
cp cli/dist-exe/bun-linux-x64-baseline/hapi \
   node_modules/.bun/@twsxtd+hapi-linux-x64@*/node_modules/@twsxtd/hapi-linux-x64/bin/hapi

# 6. 验证
hapi --version
# → hapi version: 0.18.3
```

> **回滚**: `npm install -g @twsxtd/hapi@latest` 一键恢复官方版。

> **macOS 用户**：步骤 5 中的 `bun-linux-x64-baseline` 需要换成 `bun-darwin-arm64` 或 `bun-darwin-x64`。

---

## 第二步：创建 Profile 配置文件

在用户目录下创建 `~/.hapi/claude-profiles.json`：

```bash
cp claude-profiles.sample.json ~/.hapi/claude-profiles.json
# 然后编辑里面的 command 路径和 env 变量
```

文件结构：

```json
{
  "profiles": [
    {
      "name": "default",
      "label": "Default Claude"
    },
    {
      "name": "aliyun",
      "label": "Aliyun DashScope (Qwen)",
      "command": "/home/你的用户名/bin/claude-qwen",
      "env": {
        "OPENAI_BASE_URL": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "OPENAI_MODEL": "qwen3-coder-plus"
      }
    }
  ]
}
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `name` | 是 | 唯一标识，`--profile` 传参和 Web UI 选择都用它 |
| `label` | 是 | Web UI 下拉框中显示的名字 |
| `command` | 否 | 自定义的 Claude 可执行文件路径。不填则走默认（`HAPI_CLAUDE_PATH` → PATH） |
| `env` | 否 | 启动 Claude 时额外注入的环境变量 |

> **注意**：配置文件**随时修改即时生效**，不需要重启 hapi hub 或 runner，也不需要重新编译。新增 profile 或修改 env 后，下次开会话就会应用。

---

## 第三步：启动服务

```bash
# 用项目自带的脚本启动（推荐）
./scripts/manage-hapi.sh start

# 或者手动启动
nohup hapi hub --host 0.0.0.0 > /dev/null 2>&1 &
hapi runner start
```

然后打开浏览器访问 `http://你的机器IP:3006`，用 token 登录。

---

## 第四步：使用 Profile

### 方式一：Web UI

1. 登录后点击新建会话
2. Agent 选择 **Claude**
3. 表单下方会出现 **Claude Profile** 下拉框
4. 选择你要用的 profile
5. 填写目录等其他信息，点创建

### 方式二：命令行

```bash
hapi --profile aliyun                          # 用 aliyun profile 启动本地会话
hapi --profile deepseek --yolo                 # 组合其他参数
hapi --resume --profile aliyun                 # 恢复旧会话也用同一个 profile
```

---

## 场景一：我有自己的 Claude 包装脚本

如果你的 Claude 是通过包装脚本启动的（需要设置 API 代理、Token 等）：

### 1. 创建一个包装脚本 `~/bin/claude-aliyun`

```bash
#!/bin/bash
export OPENAI_BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1"
export OPENAI_API_KEY="你的阿里云Key"
exec claude "$@"
```

```bash
chmod +x ~/bin/claude-aliyun
```

### 2. 在 Profile 里指向它

```json
{
  "name": "aliyun",
  "label": "Aliyun Qwen",
  "command": "/home/你的用户名/bin/claude-aliyun"
}
```

之后无论在 Web UI 还是命令行，HAPI 都会通过你的包装脚本启动 Claude，所有环境变量都在包装脚本里设好了。

---

## 场景二：包装脚本需要交互选择，无法修改

有些脚本（比如别人提供的）在启动前会 `read` 让用户选模型：

```bash
#!/bin/bash
echo "请选择模型: 1) coder 2) plus"
read choice
...
exec claude ...
```

这种脚本在**本机终端**可以交互，但在**远程模式**（手机/网页创会话）下因为没有终端会永远卡住。

不需要修改原脚本，只需要在它外面包一层薄壳。

### 创建薄壳 `~/bin/hapi-claude-entry`

```bash
#!/bin/bash
# ==========================================
# HAPI Claude Profile 入口薄壳
# - 有 TTY（本机终端）→ 跑原始交互脚本
# - 无 TTY（远程模式）→ 跳过交互，用 profile 预设的 env 直接起 claude
# ==========================================

ORIGINAL="/path/to/别人的交互脚本.sh"   # ← 改成你实际的脚本路径

if [ -t 0 ]; then
    # 本机终端：正常交互选择
    exec "$ORIGINAL" "$@"
else
    # 无终端（远程）：profile 里的 env 已经被 HAPI 注入
    exec claude "$@"
fi
```

```bash
chmod +x ~/bin/hapi-claude-entry
```

### Profile 配置

```json
{
  "name": "qwen-interactive",
  "label": "Qwen（本地交互选择）",
  "command": "/home/你的用户名/bin/hapi-claude-entry",
  "env": {
    "OPENAI_BASE_URL": "https://dashscope.aliyuncs.com/compatible-mode/v1",
    "OPENAI_MODEL": "qwen3-coder-plus"
  }
}
```

### 效果

| 场景 | 行为 |
|------|------|
| 终端运行 `hapi --profile qwen-interactive` | 执行原脚本，正常交互选模型 |
| 手机 / Web UI 远程创建会话 | 跳过交互，使用 profile 里预设的 `OPENAI_MODEL` |

原脚本完全不动，薄壳只负责判断有没有终端。

---

## 工作原理

### 命令解析优先级

1. Profile 里的 `command`（**最高**）
2. `HAPI_CLAUDE_PATH` 环境变量
3. 系统 PATH 里的 `claude`

### 环境变量优先级

1. Profile 里的 `env`
2. `claudeEnvVars`（CLI 启动时传入的额外变量）
3. 系统环境变量

### 创建会话时的完整数据流

```
Web UI 选 Profile
  → POST /api/machines/:id/spawn  { "profile": "aliyun", ... }
  → Hub RPCGateway 转发给 Runner
  → Runner 执行: hapi claude --profile aliyun --hapi-starting-mode remote ...
  → runClaude() 解析 --profile 参数，存入 Session
  → claudeLocal() / claudeRemote() 读取 ~/.hapi/claude-profiles.json
  → 用 profile.command + profile.env 启动 Claude 进程
```

### API

`GET /api/claude-profiles`

返回当前机器上配置的所有 profile（仅返回 `name` + `label`，**不暴露** `command` 和 `env`）。需要 Bearer Token 鉴权。

---

## 管理脚本

`scripts/manage-hapi.sh` 用于管理 hapi 后台服务：

```bash
scripts/manage-hapi.sh start      # 启动 hub + runner
scripts/manage-hapi.sh stop       # 停止
scripts/manage-hapi.sh restart    # 重启
scripts/manage-hapi.sh status     # 查看状态
```

---

## 常见问题

**Q: 增删改 profile 需要重启服务吗？**

不需要。`~/.hapi/claude-profiles.json` 在每次创建会话时实时读取。

**Q: 如何在多台机器上同步 profile？**

手动把 `~/.hapi/claude-profiles.json` 复制到每台机器即可。每台机器的 profile 是独立的，互不影响。

**Q: 如何回滚到官方版 hapi？**

```bash
npm install -g @twsxtd/hapi@latest
```

`bun link` 只建了一个 symlink，不会修改 npm 包文件。
