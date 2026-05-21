#!/bin/bash

# HAPI 服务管理脚本
# 功能: 启动、停止、重启、查看状态

SCRIPT_NAME=$(basename "$0")
HAPI_CMD="hapi"
HUB_PATTERN="hapi hub"
RUNNER_PATTERN="hapi runner"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 分隔线
print_separator() {
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
}

# 标题打印函数
print_header() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# PID 格式化函数
format_pids() {
    local pids="$1"
    if [ -n "$pids" ]; then
        echo "$pids" | tr '\n' ' ' | sed 's/ $//'
    else
        echo "无"
    fi
}

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 hapi 命令是否存在
check_hapi() {
    if ! command -v "$HAPI_CMD" >/dev/null 2>&1; then
        log_error "未找到 $HAPI_CMD 命令，请确保 hapi 已安装并配置在 PATH 中"
        exit 1
    fi
}

# 获取 hapi hub 进程 PID（换行分隔）
get_hub_pids() {
    pgrep -f "$HUB_PATTERN"
}

# 获取 hapi runner 进程 PID（换行分隔）
get_runner_pids() {
    pgrep -f "$RUNNER_PATTERN"
}

# 启动服务
start() {
    print_header "启动 HAPI 服务"
    log_info "正在启动 hapi 服务..."

    # 从 settings.json 读取 hub 端口
    local hub_port
    hub_port=$(python3 -c "import json; print(json.load(open('$HOME/.hapi/settings.json')).get('listenPort', 3006))" 2>/dev/null || echo "3006")
    local api_url="http://localhost:${hub_port}"

    # 检查 hub 是否已经运行
    local hub_pids=$(get_hub_pids)
    if [ -n "$hub_pids" ]; then
        log_warn "hapi hub 已经在运行 (PID: $(format_pids "$hub_pids"))"
    else
        log_info "启动 hapi hub..."
        nohup "$HAPI_CMD" hub --host 0.0.0.0 > /dev/null 2>&1 &

        # 等待片刻确保服务器启动
        sleep 3

        # 检查是否启动成功
        hub_pids=$(get_hub_pids)
        if [ -n "$hub_pids" ]; then
            log_info "hapi hub 启动成功 (PID: $(format_pids "$hub_pids"), 端口: $hub_port)"
        else
            log_error "hapi hub 启动失败"
            return 1
        fi
    fi

    # 启动 runner
    local runner_pids=$(get_runner_pids)
    if [ -n "$runner_pids" ]; then
        log_warn "hapi runner 已经在运行 (PID: $(format_pids "$runner_pids"))"
    else
        log_info "启动 hapi runner (连接 $api_url)..."
        nohup "$HAPI_CMD" runner start --api-url "$api_url" > /tmp/hapi-runner.log 2>&1

        # 等待片刻确保 runner 注册完成
        sleep 3

        # 验证 runner 是否真的启动了
        runner_pids=$(get_runner_pids)
        if [ -n "$runner_pids" ]; then
            log_info "hapi runner 启动成功 (PID: $(format_pids "$runner_pids"))"
        else
            log_error "hapi runner 启动失败，查看日志: /tmp/hapi-runner.log"
            tail -5 /tmp/hapi-runner.log
            return 1
        fi
    fi

    log_info "hapi 服务启动完成"
    print_separator
    return 0
}

# 停止服务
stop() {
    print_header "停止 HAPI 服务"
    log_info "正在停止 hapi 服务..."

    # 停止 runner
    log_info "停止 hapi runner..."
    if "$HAPI_CMD" runner stop >/dev/null 2>&1; then
        log_info "hapi runner 已停止"
    else
        log_warn "停止 hapi runner 时出现错误（可能未运行）"
    fi

    # 停止 hapi hub 进程
    local hub_pids=$(get_hub_pids)
    if [ -n "$hub_pids" ]; then
        log_info "正在停止 hapi hub 进程 (PID: $(format_pids "$hub_pids"))..."
        for pid in $hub_pids; do
            kill "$pid" 2>/dev/null && log_info "已发送 TERM 信号到进程 $pid"
        done

        # 等待进程结束
        local wait_time=0
        local max_wait=10
        while [ $wait_time -lt $max_wait ]; do
            hub_pids=$(get_hub_pids)
            if [ -z "$hub_pids" ]; then
                log_info "所有 hapi hub 进程已停止"
                break
            fi
            sleep 1
            wait_time=$((wait_time + 1))
        done

        # 如果还有进程，强制杀死
        hub_pids=$(get_hub_pids)
        if [ -n "$hub_pids" ]; then
            log_warn "进程未正常停止，发送 KILL 信号..."
            for pid in $hub_pids; do
                kill -9 "$pid" 2>/dev/null && log_info "已强制杀死进程 $pid"
            done
        fi
    else
        log_info "未找到运行的 hapi hub 进程"
    fi

    log_info "hapi 服务停止完成"
    print_separator
    return 0
}

# 重启服务
restart() {
    print_header "重启 HAPI 服务"
    log_info "正在重启 hapi 服务..."
    stop
    sleep 2
    start
}

# 查看状态
status() {
    print_header "HAPI 服务状态检查"
    log_info "检查 hapi 服务状态..."
    print_separator

    # 检查 hub
    local hub_pids=$(get_hub_pids)
    if [ -n "$hub_pids" ]; then
        log_info "hapi hub 正在运行 (PID: $(format_pids "$hub_pids"))"
        for pid in $hub_pids; do
            if ps -p "$pid" >/dev/null 2>&1; then
                echo "  Hub 进程 $pid: $(ps -p "$pid" -o cmd=)"
            fi
        done
    else
        log_info "hapi hub 未运行"
    fi

    # 检查 runner 状态
    print_separator
    log_info "检查 hapi runner 状态..."
    local runner_output
    runner_output=$("$HAPI_CMD" runner status 2>&1)
    local runner_exit=$?

    if [ $runner_exit -eq 0 ]; then
        log_info "hapi runner:"
        echo "$runner_output" | head -10 | while read line; do
            log_info "  $line"
        done
    else
        log_warn "hapi runner 未运行"
    fi

    return 0
}

# 显示使用说明
usage() {
    cat << EOF
用法: $SCRIPT_NAME {start|stop|restart|status|help}

管理 hapi 服务的脚本 (v0.18.x)。

命令:
    start    启动 hapi hub 和 runner
    stop     停止 hapi runner 和 hub
    restart  重启 hapi 服务
    status   查看 hapi 服务状态
    help     显示此帮助信息

示例:
    $SCRIPT_NAME start
    $SCRIPT_NAME status
    $SCRIPT_NAME stop
    $SCRIPT_NAME restart

EOF
}

# 主函数
main() {
    check_hapi

    case "$1" in
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        status)
            status
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "未知命令: $1"
            usage
            exit 1
            ;;
    esac
}

# 执行主函数
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

main "$@"
