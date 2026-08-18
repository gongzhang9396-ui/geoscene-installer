#!/usr/bin/env bash
#==============================================================================
# GeoScene Enterprise Uninstaller & Cleanup (v7.0)
# 支持: help 参数 | man 帮助 | 静默卸载 | 彻底清理 | 配置文件 | 备份恢复
# 支持: JDK/Tomcat清理 | 日志清理 | systemd服务清理 | 健康检查报告清理
#==============================================================================
set -euo pipefail
shopt -s nullglob extglob

SCRIPT_VERSION="7.0"
SCRIPT_NAME="uninstall-geoscene.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="geoscene.conf"

GS_USER="geoscene"
GS_GROUP="geoscene"
GS_HOME="/home/geoscene"
GS_BASE="/home/geoscene/geoscene"
JDK_HOME="/opt/jdk"
TOMCAT_HOME="/opt/tomcat"
SERVER_PORT="6443"
PORTAL_PORT="7443"
DATASTORE_PORT="2443"

CONFIG_FILE=""
PURGE_DATA=false
SILENT_UNINSTALL=false
FORCE_MODE=false
REMOVE_BACKUPS=false
REMOVE_LOGS=false

#==============================================================================
# 帮助函数
#==============================================================================
show_help() {
    cat << EOF
GeoScene Enterprise Uninstaller v${SCRIPT_VERSION}

用法: $SCRIPT_NAME [选项]

选项:
  -h, --help              显示此帮助信息
  --man                   显示完整手册页
  -f, --purge             彻底删除所有数据目录（包括JDK/Tomcat）
  -s, --silent            执行静默卸载（调用官方卸载程序）
  --force                 强制卸载，忽略错误
  --remove-backups        删除备份目录
  --remove-logs           删除所有日志文件
  --config=FILE           指定配置文件 (默认: $DEFAULT_CONFIG)
  --gs-user=USER          GeoScene 运行用户 (默认: geoscene)
  --gs-base=DIR           安装基础目录 (默认: /home/geoscene/geoscene)

示例:
  # 安全卸载（保留数据目录和配置）
  $SCRIPT_NAME

  # 彻底卸载（删除所有数据，包括JDK/Tomcat）
  $SCRIPT_NAME --purge

  # 彻底卸载并清理备份和日志
  $SCRIPT_NAME --purge --remove-backups --remove-logs

  # 强制彻底清理（忽略错误）
  $SCRIPT_NAME --purge --force

v7.0 清理范围:
  - systemd 服务 (geoscene-server, geoscene-portal, geoscene-datastore, geoscene-tomcat)
  - 防火墙规则 (6443, 7443, 2443, 9876, 9877, 443)
  - 系统限制配置 (limits.conf, system.conf)
  - JDK 和 Tomcat (--purge 时删除)
  - 备份目录 (--remove-backups 时删除)
  - 日志文件 (--remove-logs 时删除)
  - 专用用户和组 (--purge 时删除)
  - 安装目录 (--purge 时删除)

注意:
  - 需要 root 权限执行
  - --purge 会删除所有数据，谨慎使用
  - 卸载前建议先通过 Web 界面删除站点/门户
  - v7.0 新增: 自动清理JDK/Tomcat、备份、日志
EOF
}

show_man() {
    cat << EOF
GEOSCENE-UNINSTALL(1)        GeoScene Enterprise Uninstaller        GEOSCENE-UNINSTALL(1)

名称
    uninstall-geoscene.sh - GeoScene Enterprise 卸载清理脚本 v7.0

版本
    v${SCRIPT_VERSION}

描述
    本脚本提供 GeoScene Enterprise 的完整卸载和清理功能，
    支持安全卸载（保留数据）和彻底清理（删除所有数据）两种模式。
    v7.0 新增: JDK/Tomcat清理、备份清理、日志清理、健康报告清理。

选项
    -h, --help          显示帮助信息
    --man               显示完整手册页
    -f, --purge         彻底删除所有数据目录、JDK、Tomcat、用户home
    -s, --silent        执行静默卸载，调用官方卸载程序
    --force             强制模式，忽略错误继续执行
    --remove-backups    删除备份目录 ($GS_HOME/.geoscene_backup/)
    --remove-logs       删除所有日志文件 (/var/log/geoscene*)
    --config=FILE       指定配置文件

清理范围
    默认模式（安全卸载）:
        - 停止并移除 systemd 服务
        - 清理防火墙规则
        - 移除 limits.conf 和 system.conf 配置
        - 移除安装状态记录
        - 保留用户数据、备份、日志

    --purge 模式（彻底清理）:
        - 以上所有内容
        - 删除 JDK 安装目录
        - 删除 Tomcat 安装目录
        - 删除 GeoScene 用户和组
        - 删除用户 home 目录及所有数据
        - 删除授权文件

    --remove-backups:
        - 删除备份目录 ($GS_HOME/.geoscene_backup/)

    --remove-logs:
        - 删除安装日志 (/var/log/geoscene_*.log)
        - 删除健康检查报告 (/var/log/geoscene_health_*.txt)

工作流程
    1. 加载配置
    2. 停止所有服务（systemctl + 官方停止脚本）
    3. 执行静默卸载（可选）
    4. 移除 systemd 服务
    5. 清理防火墙规则
    6. 移除系统限制配置
    7. 删除 JDK/Tomcat（--purge）
    8. 删除备份（--remove-backups）
    9. 删除日志（--remove-logs）
    10. 删除用户和组（--purge）
    11. 删除安装目录（--purge）
    12. 验证清理结果

版本历史
    v7.0 - 新增: JDK/Tomcat清理、备份清理、日志清理、健康报告清理
    v5.1 - 配合 v5.1 安装脚本，添加配置文件支持
    v5.0 - 配合 v5.0 安装脚本
EOF
}

#==============================================================================
# 参数解析
#==============================================================================
for arg in "$@"; do
    case "$arg" in
        --help|-h) show_help; exit 0 ;;
        --man) show_man; exit 0 ;;
        --purge|-f) PURGE_DATA=true ;;
        --silent|-s) SILENT_UNINSTALL=true ;;
        --force) FORCE_MODE=true ;;
        --remove-backups) REMOVE_BACKUPS=true ;;
        --remove-logs) REMOVE_LOGS=true ;;
        --config=*) CONFIG_FILE="${arg#*=}" ;;
        --gs-user=*) GS_USER="${arg#*=}" ;;
        --gs-base=*) GS_BASE="${arg#*=}" ;;
    esac
done

#==============================================================================
# 加载配置
#==============================================================================
load_config_from_file() {
    local conf_path="$SCRIPT_DIR/$DEFAULT_CONFIG"
    [[ -n "$CONFIG_FILE" ]] && conf_path="$CONFIG_FILE"
    
    if [[ -f "$conf_path" ]]; then
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            value="${value%%#*}"
            value="${value%\"*}"; value="${value#*\"}"
            value="${value%\'}"; value="${value#*\'}"
            value=$(echo "$value" | sed 's/^ *//;s/ *$//')
            
            case "$key" in
                GS_USER) GS_USER="$value" ;;
                GS_GROUP) GS_GROUP="$value" ;;
                GS_HOME) GS_HOME="$value" ;;
                GS_BASE) GS_BASE="$value" ;;
                JDK_HOME) JDK_HOME="$value" ;;
                TOMCAT_HOME) TOMCAT_HOME="$value" ;;
                SERVER_PORT) SERVER_PORT="$value" ;;
                PORTAL_PORT) PORTAL_PORT="$value" ;;
                DATASTORE_PORT) DATASTORE_PORT="$value" ;;
            esac
        done < "$conf_path"
    fi
}

load_config_from_file

# 动态调整路径；兼容当前 /geoscenedata 部署布局。
[[ -z "$JDK_HOME" ]] && JDK_HOME="$GS_BASE/jdk"
[[ -z "$TOMCAT_HOME" ]] && TOMCAT_HOME="$GS_BASE/tomcat"
# Prefer the active GeoScene layout when it contains installed components,
# even if an old empty/default GS_BASE directory still exists.
if [[ -d "/geoscenedata/geoscene/server" || -d "/geoscenedata/geoscene/portal" || -d "/geoscenedata/geoscene/datastore" || -d "/geoscenedata/geoscene/webadaptor" || -f "/geoscenedata/geoscene/collect-logs.sh" ]]; then
    GS_BASE="/geoscenedata/geoscene"
fi
if [[ ! -d "$JDK_HOME" && -d "/geoscenedata/jdk" ]]; then
    JDK_HOME="/geoscenedata/jdk"
fi
if [[ ! -d "$TOMCAT_HOME" && -d "/geoscenedata/tomcat9" ]]; then
    TOMCAT_HOME="/geoscenedata/tomcat9"
fi

gs_component_home() {
    local comp="$1" vendor_name="$1"
    [[ "$comp" == "webadaptor" ]] && vendor_name="webAdaptor"

    local install_root="$GS_BASE/$comp"
    if [[ -d "$install_root/geoscene/$vendor_name" ]]; then
        echo "$install_root/geoscene/$vendor_name"
    elif [[ -d "$GS_BASE/geoscene/$vendor_name" ]]; then
        echo "$GS_BASE/geoscene/$vendor_name"
    else
        echo "$install_root"
    fi
}

#==============================================================================
# 常量
#==============================================================================
readonly LOG_FILE="/var/log/geoscene_uninstall_$(date +%Y%m%d_%H%M%S).log"
readonly STATE_FILE="/var/log/.geoscene_install_state"
readonly LIMITS_CONF="/etc/security/limits.d/99-geoscene.conf"
REQUIRED_PORTS=("$SERVER_PORT" "$PORTAL_PORT" "$DATASTORE_PORT" "9876" "9877" "443")

#==============================================================================
# 日志函数 - 与安装脚本保持一致
#==============================================================================
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

print_task_header() {
    local title="$1"
    echo ""
    echo -e "\033[44;37m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m"
    echo -e "\033[44;37m┃  $title\033[0m"
    echo -e "\033[44;37m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
    echo ""
}

print_subtask() {
    local title="$1"
    echo -e "\033[36m  ▶ $title\033[0m"
    log_info "$title"
}

print_subtask_success() {
    local title="$1"
    echo -e "\033[32m  ✓ $title\033[0m"
    log_success "$title"
}

print_subtask_warn() {
    local title="$1"
    echo -e "\033[33m  ⚠ $title\033[0m"
    log_warn "$title"
}

#==============================================================================
# 服务管理
#==============================================================================
stop_services() {
    print_task_header "停止 GeoScene 服务"

    # v7.0: 新增 geoscene-tomcat 服务
    for svc in geosceneserver geosceneportal geoscenedatastore geoscene-tomcat geoscene-server geoscene-portal geoscene-datastore geoscene-daemon arcgisserver arcgisportal arcgisdatastore; do
        if systemctl list-units --full -all 2>/dev/null | grep -q "${svc}.service"; then
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                print_subtask "停止 $svc..."
                systemctl stop "$svc" 2>/dev/null && print_subtask_success "$svc 已停止" || print_subtask_warn "停止 $svc 失败"
            fi
            systemctl disable "$svc" 2>/dev/null || true
        fi
    done

    # 使用官方停止脚本
    local server_home portal_home datastore_home
    server_home=$(gs_component_home server)
    portal_home=$(gs_component_home portal)
    datastore_home=$(gs_component_home datastore)

    if [[ -d "$server_home" ]]; then
        local stop_server="$server_home/stopserver.sh"
        [[ -x "$stop_server" ]] && runuser -u "$GS_USER" -- "$stop_server" 2>/dev/null || true
    fi

    if [[ -d "$portal_home" ]]; then
        local stop_portal="$portal_home/stopportal.sh"
        [[ -x "$stop_portal" ]] && runuser -u "$GS_USER" -- "$stop_portal" 2>/dev/null || true
    fi

    if [[ -d "$datastore_home" ]]; then
        local stop_ds="$datastore_home/stopdatastore.sh"
        [[ -x "$stop_ds" ]] && runuser -u "$GS_USER" -- "$stop_ds" 2>/dev/null || true
    fi

    # 停止 Tomcat
    if [[ -f "$TOMCAT_HOME/bin/shutdown.sh" ]]; then
        print_subtask "停止 Tomcat..."
        runuser -u "$GS_USER" -- "$TOMCAT_HOME/bin/shutdown.sh" 2>/dev/null || true
    fi

    sleep 3

    # 强制终止残留进程
    if pgrep -u "$GS_USER" -f "geoscene|arcgis|java|tomcat" &>/dev/null; then
        print_subtask_warn "发现残留进程，正在终止..."
        pkill -u "$GS_USER" -f "geoscene|arcgis" 2>/dev/null || true
        sleep 5
        if pgrep -u "$GS_USER" -f "geoscene|arcgis|java" &>/dev/null; then
            pkill -9 -u "$GS_USER" -f "geoscene|arcgis|java" 2>/dev/null || true
            print_subtask_warn "已强制终止残留进程"
        fi
    fi

    log_success "服务已停止"
}

#==============================================================================
# 静默卸载
#==============================================================================
silent_uninstall() {
    [[ "$SILENT_UNINSTALL" == false ]] && return 0

    print_task_header "执行静默卸载"

    local server_home portal_home datastore_home
    server_home=$(gs_component_home server)
    portal_home=$(gs_component_home portal)
    datastore_home=$(gs_component_home datastore)

    if [[ -d "$server_home" ]]; then
        local uninstaller="$server_home/uninstall_GeoSceneServer"
        [[ ! -x "$uninstaller" ]] && uninstaller="$server_home/Uninstall_ArcGIS_Server"
        [[ -x "$uninstaller" ]] && runuser -u "$GS_USER" -- "$uninstaller" -s 2>/dev/null && print_subtask_success "Server 静默卸载完成" || print_subtask_warn "Server 静默卸载失败"
    fi

    if [[ -d "$portal_home" ]]; then
        local uninstaller="$portal_home/uninstall_GeoScenePortal"
        [[ ! -x "$uninstaller" ]] && uninstaller="$portal_home/Uninstall_Portal_for_ArcGIS"
        [[ -x "$uninstaller" ]] && runuser -u "$GS_USER" -- "$uninstaller" -s 2>/dev/null && print_subtask_success "Portal 静默卸载完成" || print_subtask_warn "Portal 静默卸载失败"
    fi

    if [[ -d "$datastore_home" ]]; then
        local uninstaller="$datastore_home/uninstall_GeoSceneDataStore"
        [[ ! -x "$uninstaller" ]] && uninstaller="$datastore_home/Uninstall_ArcGIS_DataStore"
        [[ -x "$uninstaller" ]] && runuser -u "$GS_USER" -- "$uninstaller" -s 2>/dev/null && print_subtask_success "DataStore 静默卸载完成" || print_subtask_warn "DataStore 静默卸载失败"
    fi
}

#==============================================================================
# 防火墙规则清理
#==============================================================================
remove_firewall_rules() {
    print_task_header "清理防火墙规则"

    if command -v firewall-cmd &>/dev/null; then
        for p in "${REQUIRED_PORTS[@]}"; do
            firewall-cmd --permanent --remove-port="${p}/tcp" &>/dev/null || true
        done
        firewall-cmd --reload &>/dev/null || true
        print_subtask_success "firewall-cmd 规则已清理"
    elif command -v ufw &>/dev/null; then
        for p in "${REQUIRED_PORTS[@]}"; do
            ufw delete allow "${p}/tcp" &>/dev/null 2>&1 || true
        done
        ufw reload &>/dev/null || true
        print_subtask_success "ufw 规则已清理"
    fi
}

#==============================================================================
# 系统配置清理
#==============================================================================
remove_system_config() {
    print_task_header "清理系统配置"

    # limits.conf
    if [[ -f "$LIMITS_CONF" ]]; then
        rm -f "$LIMITS_CONF"
        print_subtask_success "已删除 $LIMITS_CONF"
    fi

    # system.conf GeoScene配置
    local systemd_conf="/etc/systemd/system.conf"
    if [[ -f "$systemd_conf" ]]; then
        if grep -q "# GeoScene Enterprise Configuration" "$systemd_conf" 2>/dev/null; then
            sed -i '/^# GeoScene Enterprise Configuration/,/^$/d' "$systemd_conf"
            print_subtask_success "已清理 system.conf GeoScene配置"
        fi
    fi

    # logrotate配置
    if [[ -f "/etc/sysctl.d/99-geoscene.conf" ]]; then
        rm -f "/etc/sysctl.d/99-geoscene.conf"
        sysctl --system >/dev/null 2>&1 || true
        print_subtask_success "已删除 sysctl GeoScene 配置"
    fi

    if [[ -f "/etc/sysctl.d/99-geoscene-ipv6.conf" ]]; then
        rm -f "/etc/sysctl.d/99-geoscene-ipv6.conf"
        sysctl --system >/dev/null 2>&1 || true
        print_subtask_success "已删除 IPv6 GeoScene 配置"
    fi

    if [[ -f "/etc/logrotate.d/geoscene" ]]; then
        rm -f "/etc/logrotate.d/geoscene"
        rm -f "/etc/logrotate.d/geoscene-tomcat" 2>/dev/null || true
        print_subtask_success "已删除 logrotate 配置"
    fi
}

#==============================================================================
# systemd服务清理
#==============================================================================
remove_systemd_services() {
    print_task_header "清理 systemd 服务"
    local removed=0

    # v7.0: 包含 geoscene-tomcat
    for svc in geosceneserver geosceneportal geoscenedatastore geoscene-tomcat geoscene-server geoscene-portal geoscene-datastore geoscene-daemon arcgisserver arcgisportal arcgisdatastore; do
        local svc_file="/etc/systemd/system/${svc}.service"
        if [[ -f "$svc_file" ]]; then
            systemctl stop "$svc" 2>/dev/null || true
            systemctl disable "$svc" 2>/dev/null || true
            rm -f "$svc_file"
            (( removed++ )) || true
            print_subtask_success "已移除 $svc.service"
        fi
    done

    systemctl daemon-reload 2>/dev/null || true
    systemctl reset-failed 2>/dev/null || true
    log_success "systemd 服务已清理 ($removed 个)"
}

#==============================================================================
# JDK和Tomcat清理
#==============================================================================
remove_jdk_tomcat() {
    [[ "$PURGE_DATA" == false ]] && return 0

    print_task_header "清理 JDK 和 Tomcat (--purge)"

    # 清理JDK
    if [[ -d "$JDK_HOME" ]]; then
        rm -rf "$JDK_HOME"
        print_subtask_success "已删除 JDK: $JDK_HOME"
    fi

    # 清理环境变量配置
    if [[ -f "/etc/profile.d/geoscene-jdk.sh" ]]; then
        rm -f "/etc/profile.d/geoscene-jdk.sh"
        print_subtask_success "已删除 JDK 环境变量配置"
    fi

    # 清理Tomcat
    if [[ -d "$TOMCAT_HOME" ]]; then
        rm -rf "$TOMCAT_HOME"
        print_subtask_success "已删除 Tomcat: $TOMCAT_HOME"
    fi
}

#==============================================================================
# 备份清理
#==============================================================================
remove_backups() {
    [[ "$REMOVE_BACKUPS" == false ]] && return 0

    print_task_header "清理备份目录 (--remove-backups)"

    local backup_dir="$GS_HOME/.geoscene_backup"
    if [[ -d "$backup_dir" ]]; then
        rm -rf "$backup_dir"
        print_subtask_success "已删除备份目录: $backup_dir"
    else
        print_subtask_warn "备份目录不存在"
    fi
}

#==============================================================================
# 日志清理
#==============================================================================
remove_logs() {
    [[ "$REMOVE_LOGS" == false ]] && return 0

    print_task_header "清理日志文件 (--remove-logs)"

    # 安装日志
    local log_count=0
    for log_file in /var/log/geoscene_*.log /var/log/geoscene_health_*.txt /var/log/geoscene_uninstall_*.log; do
        [[ -f "$log_file" ]] && rm -f "$log_file" && (( log_count++ )) || true
    done

    # 状态文件
    [[ -f "$STATE_FILE" ]] && rm -f "$STATE_FILE"

    print_subtask_success "已删除 $log_count 个日志文件"
}

#==============================================================================
# 用户和组清理
#==============================================================================
remove_user() {
    [[ "$PURGE_DATA" == false ]] && return 0

    print_task_header "清理用户和组 (--purge)"

    if id "$GS_USER" &>/dev/null; then
        pkill -9 -u "$GS_USER" 2>/dev/null || true
        sleep 1

        userdel "$GS_USER" 2>/dev/null || userdel -f "$GS_USER" 2>/dev/null || {
            [[ "$FORCE_MODE" == true ]] && print_subtask_warn "强制模式: 用户删除失败但继续" || {
                log_error "无法删除用户 $GS_USER"
                return 1
            }
        }
        print_subtask_success "用户 $GS_USER 已删除"

        # 删除home目录
        if [[ -d "$GS_HOME" ]]; then
            rm -rf "$GS_HOME"
            print_subtask_success "已删除 home 目录: $GS_HOME"
        fi
    else
        print_subtask_warn "用户 $GS_USER 不存在"
    fi

    if getent group "$GS_GROUP" &>/dev/null; then
        groupdel "$GS_GROUP" 2>/dev/null || true
        print_subtask_success "组 $GS_GROUP 已删除"
    fi
}

#==============================================================================
# 安装目录清理
#==============================================================================
remove_installation() {
    [[ "$PURGE_DATA" == false ]] && return 0

    print_task_header "清理安装目录 (--purge)"

    local install_dirs=("$GS_BASE/server" "$GS_BASE/portal" "$GS_BASE/datastore" "$GS_BASE/webadaptor")
    for dir in "${install_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_subtask "删除 $(basename "$dir")..."
            rm -rf "$dir"
        fi
    done

    # 安装脚本在 GS_BASE 根目录生成的辅助文件
    rm -f "$GS_BASE/collect-logs.sh"

    # 清理基础目录（如果为空）
    if [[ -d "$GS_BASE" ]] && [[ -z "$(ls -A "$GS_BASE" 2>/dev/null)" ]]; then
        rm -rf "$GS_BASE"
        print_subtask_success "已删除空目录: $GS_BASE"
    fi

    log_success "安装目录已清理"
}

#==============================================================================
# 验证清理
#==============================================================================
verify_cleanup() {
    print_task_header "验证清理结果"
    local found_issues=false

    # 检查残留进程
    if pgrep -u "$GS_USER" &>/dev/null; then
        log_error "仍有 $GS_USER 用户的进程在运行"
        ps -u "$GS_USER" -f
        found_issues=true
    fi

    # 检查残留目录 (--purge模式)
    if [[ "$PURGE_DATA" == true ]]; then
        if [[ -d "$GS_BASE/server" ]]; then
            log_error "Server 目录仍存在: $GS_BASE/server"
            found_issues=true
        fi
        if [[ -d "$GS_BASE/portal" ]]; then
            log_error "Portal 目录仍存在: $GS_BASE/portal"
            found_issues=true
        fi
        if [[ -d "$JDK_HOME" ]]; then
            log_warn "JDK 目录仍存在: $JDK_HOME"
        fi
        if [[ -d "$TOMCAT_HOME" ]]; then
            log_warn "Tomcat 目录仍存在: $TOMCAT_HOME"
        fi
    fi

    if [[ "$found_issues" == true ]]; then
        [[ "$FORCE_MODE" == true ]] && print_subtask_warn "强制模式: 存在残留但继续" || print_subtask_warn "清理未完全完成，建议重启后再次运行"
    else
        log_success "清理验证通过"
    fi
}

#==============================================================================
# 主函数
#==============================================================================
main() {
    [[ $EUID -ne 0 ]] && { echo "[ERROR] 需 root 权限执行" >&2; exit 1; }

    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    echo -e "\033[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[34m  🧹 GeoScene Uninstaller v${SCRIPT_VERSION}\033[0m"
    [[ "$PURGE_DATA" == true ]] && echo -e "\033[31m  ⚠️  模式: 彻底清理 (--purge)\033[0m"
    [[ "$REMOVE_BACKUPS" == true ]] && echo -e "\033[31m  ⚠️  将删除备份\033[0m"
    [[ "$REMOVE_LOGS" == true ]] && echo -e "\033[31m  ⚠️  将删除日志\033[0m"
    [[ "$FORCE_MODE" == true ]] && echo -e "\033[33m  ⚡ 模式: 强制执行 (--force)\033[0m"
    echo -e "\033[34m  📋 日志: $LOG_FILE\033[0m"
    echo -e "\033[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

    # 检测安装
    local detected=()
    [[ -d "$(gs_component_home server)" ]] && detected+=("server")
    [[ -d "$(gs_component_home portal)" ]] && detected+=("portal")
    [[ -d "$(gs_component_home datastore)" ]] && detected+=("datastore")
    [[ -d "$JDK_HOME" ]] && detected+=("jdk")
    [[ -d "$TOMCAT_HOME" ]] && detected+=("tomcat")

    if [[ ${#detected[@]} -gt 0 ]]; then
        log_info "检测到以下安装:"
        for d in "${detected[@]}"; do
            log_info "  - $d"
        done
    else
        log_warn "未检测到标准安装目录"
    fi

    # 执行卸载步骤
    stop_services
    silent_uninstall
    remove_systemd_services
    remove_firewall_rules
    remove_system_config
    remove_jdk_tomcat
    remove_backups
    remove_logs
    remove_user
    remove_installation
    verify_cleanup

    log_success "卸载完成。日志: $LOG_FILE"

    if [[ "$PURGE_DATA" == false ]]; then
        echo ""
        log_warn "提示: 如需彻底删除所有数据，请使用: bash $SCRIPT_NAME --purge"
        log_warn "提示: 如需删除备份，请使用: bash $SCRIPT_NAME --remove-backups"
        log_warn "提示: 如需删除日志，请使用: bash $SCRIPT_NAME --remove-logs"
    fi
}

main "$@"
