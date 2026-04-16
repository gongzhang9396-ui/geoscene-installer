#!/usr/bin/env bash
#==============================================================================
# GeoScene Enterprise Uninstaller & Cleanup (v5.1)
# 支持: help 参数 | man 帮助 | 静默卸载 | 彻底清理 | 配置文件
#==============================================================================
set -euo pipefail
shopt -s nullglob extglob

SCRIPT_VERSION="5.1"
SCRIPT_NAME="uninstall-geoscene.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="geoscene.conf"

GS_USER="geoscene"
GS_GROUP="geoscene"
GS_HOME="/home/geoscene"
GS_BASE="/home/geoscene/geoscene"
SERVER_PORT="6443"
PORTAL_PORT="7443"
DATASTORE_PORT="2443"

CONFIG_FILE=""
PURGE_DATA=false
SILENT_UNINSTALL=false
FORCE_MODE=false

show_help() {
    echo "
GeoScene Enterprise Uninstaller v${SCRIPT_VERSION}

用法: $SCRIPT_NAME [选项]

选项:
  -h, --help              显示此帮助信息
  --man                   显示完整手册页
  -f, --purge             彻底删除所有数据目录
  -s, --silent            执行静默卸载（调用官方卸载程序）
  --force                 强制卸载，忽略错误
  --config=FILE           指定配置文件 (默认: $DEFAULT_CONFIG)
  --gs-user=USER          GeoScene 运行用户 (默认: geoscene)
  --gs-base=DIR           安装基础目录 (默认: /home/geoscene/geoscene)

示例:
  # 安全卸载（保留数据目录）
  $SCRIPT_NAME

  # 使用配置文件卸载
  $SCRIPT_NAME --config=geoscene.conf

  # 静默卸载并保留数据
  $SCRIPT_NAME --silent

  # 彻底卸载并删除所有数据
  $SCRIPT_NAME --purge

  # 强制彻底清理
  $SCRIPT_NAME --purge --force

清理范围:
  - systemd 服务
  - 防火墙规则
  - 系统限制配置
  - 专用用户和组 (--purge 时删除)
  - 安装目录 (--purge 时删除)
  - 授权文件
  - 安装状态记录
  - 临时解压目录

注意:
  - 需要 root 权限执行
  - --purge 会删除所有数据，谨慎使用
  - 卸载前建议先通过 Web 界面删除站点/门户
"
}

show_man() {
    echo "
GEOSCENE-UNINSTALL(1)        GeoScene Enterprise Uninstaller        GEOSCENE-UNINSTALL(1)

名称
    uninstall-geoscene.sh - GeoScene Enterprise 卸载清理脚本

版本
    v${SCRIPT_VERSION}

描述
    本脚本提供 GeoScene Enterprise 的完整卸载和清理功能，
    支持安全卸载（保留数据）和彻底清理（删除所有数据）两种模式。

选项
    -h, --help      显示帮助信息
    --man           显示完整手册页
    -f, --purge     彻底删除所有数据目录和用户 home 目录
    -s, --silent    执行静默卸载，调用官方卸载程序
    --force         强制模式，忽略错误继续执行

工作流程
    1. 检测安装目录
    2. 停止所有服务
    3. 执行静默卸载（可选）
    4. 移除 systemd 服务
    5. 清理防火墙规则
    6. 移除系统限制配置
    7. 删除用户和组 (--purge)
    8. 删除安装目录 (--purge)
    9. 清理临时文件和授权文件
    10. 验证清理结果

清理内容
    默认模式（安全卸载）:
        - systemd 服务文件
        - 防火墙规则
        - limits 配置
        - 状态记录文件
        - 临时解压目录
        - 授权文件副本
        - 安装日志（可选）

    --purge 模式（彻底清理）:
        - 以上所有内容
        - geoscene 用户和组
        - /home/geoscene 整个目录
        - 所有安装程序目录

日志
    /var/log/geoscene_uninstall_YYYYMMDD_HHMMSS.log

警告
    使用 --purge 选项将永久删除所有 GeoScene 数据，
    包括站点配置、门户内容、服务数据等，
    此操作不可恢复，请务必提前备份重要数据。

作者
    GeoScene Installer Team

版本历史
    v5.1 - 配合 v5.1 安装脚本，添加配置文件支持
    v5.0 - 配合 v5.0 安装脚本

SEE ALSO
    install-geoscene.sh(1)
"
}

for arg in "$@"; do
    [[ "$arg" == "--help" || "$arg" == "-h" ]] && { show_help; exit 0; }
    [[ "$arg" == "--man" ]] && { show_man; exit 0; }
    [[ "$arg" == "--purge" || "$arg" == "-f" ]] && PURGE_DATA=true
    [[ "$arg" == "--silent" || "$arg" == "-s" ]] && SILENT_UNINSTALL=true
    [[ "$arg" == "--force" ]] && FORCE_MODE=true
    [[ "$arg" =~ ^--config= ]] && CONFIG_FILE="${arg#*=}"
    [[ "$arg" =~ ^--gs-user= ]] && GS_USER="${arg#*=}"
    [[ "$arg" =~ ^--gs-base= ]] && GS_BASE="${arg#*=}"
done

load_config_from_file() {
    local conf_path="$SCRIPT_DIR/$DEFAULT_CONFIG"
    [[ -n "$CONFIG_FILE" ]] && conf_path="$CONFIG_FILE"
    
    if [[ -f "$conf_path" ]]; then
        echo "[INFO] 加载配置文件: $conf_path"
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            value="${value%%#*}"
            value="${value%\"*}"; value="${value#*\"}"
            value="${value%\'}"; value="${value#*\'}"
            value=$(echo "$value" | sed 's/^ *//;s/ *$//')
            
            case "$key" in
                GS_USER)        [[ -n "$value" ]] && GS_USER="$value" ;;
                GS_GROUP)       [[ -n "$value" ]] && GS_GROUP="$value" ;;
                GS_HOME)        [[ -n "$value" ]] && GS_HOME="$value" ;;
                GS_BASE)        [[ -n "$value" ]] && GS_BASE="$value" ;;
                SERVER_PORT)    [[ -n "$value" ]] && SERVER_PORT="$value" ;;
                PORTAL_PORT)    [[ -n "$value" ]] && PORTAL_PORT="$value" ;;
                DATASTORE_PORT) [[ -n "$value" ]] && DATASTORE_PORT="$value" ;;
            esac
        done < "$conf_path"
        echo "[SUCCESS] 配置文件已加载"
    fi
}

load_config_from_file

if [[ "$GS_HOME" == "/home/geoscene" && "$GS_USER" != "geoscene" ]]; then
    GS_HOME="/home/$GS_USER"
fi
if [[ "$GS_BASE" == "/home/geoscene/geoscene" && "$GS_USER" != "geoscene" ]]; then
    GS_BASE="$GS_HOME/geoscene"
fi

readonly LOG_FILE="/var/log/geoscene_uninstall_$(date +%Y%m%d_%H%M%S).log"
readonly STATE_FILE="/var/log/.geoscene_install_state"
readonly LIMITS_CONF="/etc/security/limits.d/99-geoscene.conf"
REQUIRED_PORTS=("$SERVER_PORT" "$PORTAL_PORT" "$DATASTORE_PORT" "9876" "9877")

log() {
    local level="$1" color="$2" msg="$3"
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    local plain="[$level] $ts $msg"
    echo -e "\033[${color}m${plain}\033[0m"
    echo "$plain" >> "$LOG_FILE"
}
log_info()    { log "INFO"    "34" "$1"; }
log_warn()    { log "WARN"    "33" "$1"; }
log_error()   { log "ERROR"   "31" "$1"; }
log_success() { log "SUCCESS" "32" "$1"; }

detect_install_dirs() {
    local dirs=()
    [[ -d "$GS_BASE/server" ]] && dirs+=("$GS_BASE/server")
    [[ -d "$GS_BASE/portal" ]] && dirs+=("$GS_BASE/portal")
    [[ -d "$GS_BASE/datastore" ]] && dirs+=("$GS_BASE/datastore")
    [[ -d "/opt/geoscene" ]] && dirs+=("/opt/geoscene")
    echo "${dirs[@]}"
}

stop_services() {
    log_info "🛑 停止 GeoScene 相关服务..."

    for svc in geoscene-server geoscene-portal geoscene-datastore geoscene-daemon arcgisserver arcgisportal arcgisdatastore; do
        if systemctl list-units --full -all | grep -q "${svc}.service" 2>/dev/null; then
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                systemctl stop "$svc" 2>/dev/null && log_info "已停止 $svc" || log_warn "停止 $svc 失败"
            fi
            systemctl disable "$svc" 2>/dev/null || true
        fi
    done

    if [[ -d "$GS_BASE/server" ]]; then
        local stop_server="$GS_BASE/server/stopserver.sh"
        [[ -x "$stop_server" ]] && runuser -u "$GS_USER" -- "$stop_server" 2>/dev/null || true
    fi

    if [[ -d "$GS_BASE/portal" ]]; then
        local stop_portal="$GS_BASE/portal/stopportal.sh"
        [[ -x "$stop_portal" ]] && runuser -u "$GS_USER" -- "$stop_portal" 2>/dev/null || true
    fi

    if [[ -d "$GS_BASE/datastore" ]]; then
        local stop_ds="$GS_BASE/datastore/stopdatastore.sh"
        [[ -x "$stop_ds" ]] && runuser -u "$GS_USER" -- "$stop_ds" 2>/dev/null || true
    fi

    sleep 3
    if pgrep -u "$GS_USER" -f "geoscene|arcgis|java|tomcat" &>/dev/null; then
        log_warn "发现残留进程，正在终止..."
        pkill -u "$GS_USER" -f "geoscene|arcgis" 2>/dev/null || true
        sleep 5
        if pgrep -u "$GS_USER" -f "geoscene|arcgis|java" &>/dev/null; then
            pkill -9 -u "$GS_USER" -f "geoscene|arcgis|java" 2>/dev/null || true
            log_warn "已强制终止残留进程"
        fi
    fi

    log_success "服务已停止"
}

silent_uninstall() {
    [[ "$SILENT_UNINSTALL" == false ]] && return 0

    log_info "🔧 执行静默卸载..."

    if [[ -d "$GS_BASE/server" ]]; then
        local uninstaller="$GS_BASE/server/Uninstall_ArcGIS_Server"
        [[ -x "$uninstaller" ]] && runuser -u "$GS_USER" -- "$uninstaller" -s 2>/dev/null && log_info "Server 静默卸载完成" || log_warn "Server 静默卸载失败或不存在"
    fi

    if [[ -d "$GS_BASE/portal" ]]; then
        local uninstaller="$GS_BASE/portal/Uninstall_Portal_for_ArcGIS"
        [[ -x "$uninstaller" ]] && runuser -u "$GS_USER" -- "$uninstaller" -s 2>/dev/null && log_info "Portal 静默卸载完成" || log_warn "Portal 静默卸载失败或不存在"
    fi

    if [[ -d "$GS_BASE/datastore" ]]; then
        local uninstaller="$GS_BASE/datastore/Uninstall_ArcGIS_DataStore"
        [[ -x "$uninstaller" ]] && runuser -u "$GS_USER" -- "$uninstaller" -s 2>/dev/null && log_info "DataStore 静默卸载完成" || log_warn "DataStore 静默卸载失败或不存在"
    fi
}

remove_firewall_rules() {
    log_info "🔥 清理防火墙规则..."
    if command -v firewall-cmd &>/dev/null; then
        for p in "${REQUIRED_PORTS[@]}"; do
            firewall-cmd --permanent --remove-port="${p}/tcp" &>/dev/null || true
        done
        firewall-cmd --reload &>/dev/null || true
        log_info "firewall-cmd 规则已清理"
    elif command -v ufw &>/dev/null; then
        for p in "${REQUIRED_PORTS[@]}"; do
            ufw delete allow "${p}/tcp" &>/dev/null 2>&1 || true
        done
        ufw reload &>/dev/null || true
        log_info "ufw 规则已清理"
    fi
    log_success "防火墙规则已处理"
}

remove_limits() {
    log_info "📉 移除系统限制配置..."
    [[ -f "$LIMITS_CONF" ]] && rm -f "$LIMITS_CONF" && log_info "已删除 $LIMITS_CONF" || log_info "$LIMITS_CONF 不存在，跳过"
    log_success "limits 配置已处理"
}

remove_systemd() {
    log_info "⚙️  移除 systemd 服务..."
    local removed=0

    for svc in geoscene-server geoscene-portal geoscene-datastore geoscene-daemon arcgisserver arcgisportal arcgisdatastore; do
        local svc_file="/etc/systemd/system/${svc}.service"
        if [[ -f "$svc_file" ]]; then
            systemctl stop "$svc" 2>/dev/null || true
            systemctl disable "$svc" 2>/dev/null || true
            rm -f "$svc_file"
            (( removed++ )) || true
            log_info "已移除 $svc.service"
        fi
    done

    systemctl daemon-reload 2>/dev/null || true
    systemctl reset-failed 2>/dev/null || true
    log_success "systemd 服务已清理 ($removed 个文件)"
}

remove_user() {
    log_info "👤 清理专用用户..."
    if id "$GS_USER" &>/dev/null; then
        pkill -9 -u "$GS_USER" 2>/dev/null || true
        sleep 1

        userdel "$GS_USER" 2>/dev/null || userdel -f "$GS_USER" 2>/dev/null || {
            [[ "$FORCE_MODE" == true ]] && log_warn "强制模式: 用户删除失败但继续执行" || {
                log_error "无法删除用户 $GS_USER"
                return 1
            }
        }
        log_info "用户 $GS_USER 已删除"

        if [[ "$PURGE_DATA" == true ]]; then
            [[ -d "$GS_HOME" ]] && rm -rf "$GS_HOME" && log_info "已删除 home: $GS_HOME"
        else
            [[ -d "$GS_HOME" ]] && log_warn "保留 home 目录: $GS_HOME (--purge 可删除)"
        fi
    else
        log_info "用户 $GS_USER 不存在，跳过"
    fi

    if getent group "$GS_GROUP" &>/dev/null; then
        groupdel "$GS_GROUP" 2>/dev/null || true
        log_info "组 $GS_GROUP 已删除"
    fi
    log_success "用户与组已处理"
}

remove_directories() {
    log_info "🗑️  清理安装目录..."

    local install_dirs
    install_dirs=$(detect_install_dirs)

    if [[ "$PURGE_DATA" == true ]]; then
        for dir in $install_dirs; do
            if [[ -d "$dir" ]]; then
                log_warn "⚠️  正在删除 $dir"
                rm -rf "$dir" || [[ "$FORCE_MODE" == true ]] && log_warn "强制模式: 删除失败但继续"
                log_info "已删除 $dir"
            fi
        done

        if [[ -d "$GS_BASE" ]]; then
            rm -rf "$GS_BASE" || [[ "$FORCE_MODE" == true ]] && log_warn "强制模式: 删除失败但继续"
            log_info "已删除 $GS_BASE"
        fi

        log_success "数据目录已彻底清除"
    else
        for dir in $install_dirs; do
            [[ -d "$dir" ]] && log_warn "发现安装目录: $dir （使用 --purge 彻底删除）"
        done
        [[ -d "$GS_BASE" ]] && log_warn "发现基础目录: $GS_BASE （使用 --purge 彻底删除）"
        log_info "安全模式：未删除任何数据"
    fi
}

cleanup_artifacts() {
    log_info "🧽 清理残留标记与临时文件..."
    rm -f "$STATE_FILE" /var/log/.geoscene_install_state 2>/dev/null || true
    find /tmp -maxdepth 1 -type d -name "geoscene_inst_*" -exec rm -rf {} + 2>/dev/null || true
    find /tmp -maxdepth 1 -type d -name "arcgis_*" -exec rm -rf {} + 2>/dev/null || true
    find "$GS_BASE" -name ".geoscene_installed" -delete 2>/dev/null || true
    rm -f "$GS_HOME"/*.prvc "$GS_HOME"/*.json "$GS_HOME"/*.ecl "$GS_HOME"/*.lic "$GS_HOME"/*.ecp 2>/dev/null || true
    rm -f "$GS_HOME"/site_config.json "$GS_HOME"/portal_config.json "$GS_HOME"/datastore_config.json 2>/dev/null || true
    log_success "临时文件已清理"
}

verify_cleanup() {
    log_info "🔍 验证清理结果..."
    local found_issues=false

    if pgrep -u "$GS_USER" &>/dev/null; then
        log_error "仍有 $GS_USER 用户的进程在运行"
        ps -u "$GS_USER" -f
        found_issues=true
    fi

    if [[ "$PURGE_DATA" == true ]]; then
        if [[ -d "$GS_BASE/server" ]]; then
            log_error "Server 目录仍存在: $GS_BASE/server"
            found_issues=true
        fi
        if [[ -d "$GS_BASE/portal" ]]; then
            log_error "Portal 目录仍存在: $GS_BASE/portal"
            found_issues=true
        fi
    fi

    if [[ "$found_issues" == true ]]; then
        [[ "$FORCE_MODE" == true ]] && log_warn "强制模式: 存在残留但继续完成" || log_warn "清理未完全完成，建议重启后再次运行"
    else
        log_success "✅ 清理验证通过"
    fi
}

main() {
    [[ $EUID -ne 0 ]] && { echo "[ERROR] 需 root 权限执行" >&2; exit 1; }

    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    log_info "=================================================="
    log_info "  🧹 GeoScene Uninstaller v${SCRIPT_VERSION}"
    [[ "$PURGE_DATA" == true ]] && log_warn "  ⚠️  模式: 彻底清理 (--purge)"
    [[ "$SILENT_UNINSTALL" == true ]] && log_info "  🔧 模式: 静默卸载 (--silent)"
    [[ "$FORCE_MODE" == true ]] && log_warn "  ⚡ 模式: 强制执行 (--force)"
    log_info "  📋 日志: $LOG_FILE"
    log_info "=================================================="

    local detected
    detected=$(detect_install_dirs)
    if [[ -n "$detected" ]]; then
        log_info "检测到以下安装目录:"
        for d in $detected; do
            log_info "  - $d"
        done
    else
        log_warn "未检测到标准安装目录"
    fi

    stop_services
    silent_uninstall
    remove_systemd
    remove_firewall_rules
    remove_limits
    remove_user
    remove_directories
    cleanup_artifacts
    verify_cleanup

    log_success "✅ 卸载完成。日志: $LOG_FILE"

    if [[ "$PURGE_DATA" == false ]]; then
        echo ""
        log_warn "提示: 如需彻底删除所有数据，请使用: bash $SCRIPT_NAME --purge"
    fi
}
main "$@"