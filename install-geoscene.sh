#!/usr/bin/env bash
#==============================================================================
# GeoScene Enterprise Universal Installer (v5.1)
# 支持: 全自动化安装配置 | 实际IP网络配置 | 异常提示浏览器处理
# 支持: help 参数 | 配置文件 | 静默模式 | DRY-RUN 模式 | 重试机制
#==============================================================================
set -euo pipefail
shopt -s nullglob extglob

SCRIPT_VERSION="5.1"
SCRIPT_NAME="install-geoscene.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="geoscene.conf"

#==============================================================================
# 默认变量定义（可通过配置文件覆盖）
#==============================================================================
GS_USER="geoscene"
GS_GROUP="geoscene"
GS_HOME="/home/geoscene"
GS_BASE="/home/geoscene/geoscene"
SERVER_PORT="6443"
PORTAL_PORT="7443"
DATASTORE_PORT="2443"
MIN_RAM_MB="8192"
MIN_CPU_CORES="4"
MIN_DISK_HOME_GB="20"
MIN_DISK_INSTALL_GB="30"

SITE_ADMIN_USER="siteadmin"
SITE_ADMIN_PASS="YourPassword123"
PORTAL_ADMIN_USER="portaladmin"
PORTAL_ADMIN_PASS="YourPassword123"
PORTAL_ADMIN_EMAIL="portaladmin@example.com"
PORTAL_ADMIN_FN="Admin"
PORTAL_ADMIN_LN="User"
PORTAL_ADMIN_QI="1"
PORTAL_ADMIN_QA="Beijing"

CONFIG_FILE=""
DRY_RUN=false
SKIP_CONFIG=false
HOST_IP=""

#==============================================================================
# 帮助函数定义（必须在参数解析前）
#==============================================================================
show_help() {
    echo "
GeoScene Enterprise Installer v${SCRIPT_VERSION}

用法: $SCRIPT_NAME [选项]

选项:
  -h, --help              显示此帮助信息
  --man                   显示完整手册页
  -n, --dry-run           预演模式，不执行实际变更
  --config=FILE           指定配置文件 (默认: $DEFAULT_CONFIG)
  --skip-config           仅安装软件，跳过站点配置
  --gs-user=USER          GeoScene 运行用户 (默认: geoscene)
  --gs-base=DIR           安装基础目录 (默认: /home/geoscene/geoscene)

示例:
  # 使用配置文件全自动安装
  $SCRIPT_NAME --config=geoscene.conf

  # 仅安装软件，跳过自动化配置
  $SCRIPT_NAME --skip-config

  # 预演模式
  $SCRIPT_NAME --dry-run

配置文件格式 (geoscene.conf):
  # 用户和目录配置
  GS_USER=geoscene
  GS_GROUP=geoscene
  GS_HOME=/home/geoscene
  GS_BASE=/home/geoscene/geoscene
  
  # 端口配置
  SERVER_PORT=6443
  PORTAL_PORT=7443
  DATASTORE_PORT=2443
  
  # 管理员账户配置（用于自动创建站点）
  SITE_ADMIN_USER=siteadmin
  SITE_ADMIN_PASS=YourPassword123
  PORTAL_ADMIN_USER=portaladmin
  PORTAL_ADMIN_PASS=YourPassword123
  PORTAL_ADMIN_EMAIL=portaladmin@example.com
  PORTAL_ADMIN_FN=Admin
  PORTAL_ADMIN_LN=User
  PORTAL_ADMIN_QI=1
  PORTAL_ADMIN_QA=Beijing
  
  # 资源要求
  MIN_RAM_MB=8192
  MIN_CPU_CORES=4
  MIN_DISK_HOME_GB=20
  MIN_DISK_INSTALL_GB=30

工作流程:
  1. 前置校验 (权限、资源、端口)
  2. 系统配置 (用户、防火墙、limits)
  3. 软件安装 (解压、Setup 静默安装)
  4. Server 授权 (自动执行)
  5. Server 站点创建 (自动执行)
  6. Portal 门户创建 (自动执行)
  7. Portal 授权导入 (自动执行)
  8. DataStore 配置 (自动执行)

注意:
  - 需要 root 权限执行
  - 安装包和授权文件需放在脚本同目录
  - 授权文件命名需包含 server/portal/enterprise 关键字
  - 自动化配置失败时会提示用户浏览器手动处理
"
}

show_man() {
    echo "
GEOSCENE-INSTALL(1)          GeoScene Enterprise Installer          GEOSCENE-INSTALL(1)

名称
    install-geoscene.sh - GeoScene Enterprise 全自动化安装脚本

版本
    v${SCRIPT_VERSION}

描述
    本脚本提供 GeoScene Enterprise (Server, Portal, DataStore) 的全自动安装部署，
    包括软件安装、授权、站点创建、门户初始化、DataStore配置等所有步骤。
    使用实际服务器IP进行配置，避免localhost带来的网络问题。

依赖
    - Linux x86_64 系统 (CentOS 7+/Ubuntu 18+/RHEL 7+)
    - root 权限
    - 至少 ${MIN_RAM_MB}MB 内存和 ${MIN_DISK_HOME_GB}GB 磁盘空间
    - 端口 ${SERVER_PORT}, ${PORTAL_PORT}, ${DATASTORE_PORT}, 9876, 9877 可用

配置变量
    用户和目录:
        GS_USER      - GeoScene 运行用户 (默认: geoscene)
        GS_GROUP     - GeoScene 用户组 (默认: geoscene)
        GS_HOME      - 用户 home 目录 (默认: /home/geoscene)
        GS_BASE      - 安装基础目录 (默认: /home/geoscene/geoscene)
    
    端口配置:
        SERVER_PORT      - Server HTTPS 端口 (默认: 6443)
        PORTAL_PORT      - Portal HTTPS 端口 (默认: 7443)
        DATASTORE_PORT   - DataStore HTTPS 端口 (默认: 2443)
    
    管理员账户:
        SITE_ADMIN_USER     - Server 站点管理员 (默认: siteadmin)
        SITE_ADMIN_PASS     - Server 站点密码 (默认: YourPassword123)
        PORTAL_ADMIN_USER   - Portal 管理员 (默认: portaladmin)
        PORTAL_ADMIN_PASS   - Portal 密码 (默认: YourPassword123)
        PORTAL_ADMIN_EMAIL  - Portal 管理员邮箱
        PORTAL_ADMIN_FN     - Portal 管理员名
        PORTAL_ADMIN_LN     - Portal 管理员姓
        PORTAL_ADMIN_QI     - Portal 安全问题ID
        PORTAL_ADMIN_QA     - Portal 安全问题答案
    
    资源要求:
        MIN_RAM_MB         - 最小内存 MB (默认: 8192)
        MIN_CPU_CORES      - 最小CPU核数 (默认: 4)
        MIN_DISK_HOME_GB   - home目录磁盘 GB (默认: 20)
        MIN_DISK_INSTALL_GB - 安装目录磁盘 GB (默认: 30)

文件
    安装包 (必需):
        GeoScene_Server_Linux_*.tar.gz     - Server 安装包
        GeoScene_Portal_Linux_*.tar.gz     - Portal 安装包
        GeoScene_DataStore_Linux_*.tar.gz  - DataStore 安装包

    授权文件 (必需，用于自动化配置):
        *server*.prvc 或 *.ecp             - Server 授权文件
        *portal*.json 或 *enterprise*.json - Portal 授权文件

    配置文件 (可选):
        geoscene.conf                      - 所有配置变量

工作流程
    1. 前置校验 (权限、资源、端口)
    2. 系统配置 (用户、防火墙、limits)
    3. 软件安装 (解压、Setup 静默安装)
    4. Server 授权 (authorizeSoftware)
    5. Server 站点创建 (createsite.sh)
    6. Portal 门户创建 (createportal.sh)
    7. Portal 授权导入 (授权文件已在门户创建时导入)
    8. DataStore 配置 (configuredatastore.sh)

日志
    /var/log/geoscene_YYYYMMDD_HHMMSS.log

作者
    GeoScene Installer Team

版本历史
    v5.1 - 增强稳定性：添加重试逻辑、状态检测、等待机制优化
    v5.0 - 全自动化配置，使用实际IP，异常提示浏览器处理

SEE ALSO
    uninstall-geoscene.sh(1)

BUGS
    反馈问题请联系技术支持
"
}

#==============================================================================
# 解析命令行参数（先解析 --config 以便尽早加载配置）
#==============================================================================
for arg in "$@"; do
    [[ "$arg" == "--dry-run" || "$arg" == "-n" ]] && DRY_RUN=true
    [[ "$arg" == "--help" || "$arg" == "-h" ]] && { show_help; exit 0; }
    [[ "$arg" == "--man" ]] && { show_man; exit 0; }
    [[ "$arg" == "--skip-config" ]] && SKIP_CONFIG=true
    [[ "$arg" =~ ^--config= ]] && CONFIG_FILE="${arg#*=}"
    [[ "$arg" =~ ^--gs-user= ]] && GS_USER="${arg#*=}"
    [[ "$arg" =~ ^--gs-base= ]] && GS_BASE="${arg#*=}"
done

#==============================================================================
# 加载配置文件（覆盖默认值）
#==============================================================================
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
                GS_USER)               [[ -n "$value" ]] && GS_USER="$value" ;;
                GS_GROUP)              [[ -n "$value" ]] && GS_GROUP="$value" ;;
                GS_HOME)               [[ -n "$value" ]] && GS_HOME="$value" ;;
                GS_BASE)               [[ -n "$value" ]] && GS_BASE="$value" ;;
                SERVER_PORT)           [[ -n "$value" ]] && SERVER_PORT="$value" ;;
                PORTAL_PORT)           [[ -n "$value" ]] && PORTAL_PORT="$value" ;;
                DATASTORE_PORT)        [[ -n "$value" ]] && DATASTORE_PORT="$value" ;;
                SITE_ADMIN_USER)       [[ -n "$value" ]] && SITE_ADMIN_USER="$value" ;;
                SITE_ADMIN_PASS)       [[ -n "$value" ]] && SITE_ADMIN_PASS="$value" ;;
                PORTAL_ADMIN_USER)     [[ -n "$value" ]] && PORTAL_ADMIN_USER="$value" ;;
                PORTAL_ADMIN_PASS)     [[ -n "$value" ]] && PORTAL_ADMIN_PASS="$value" ;;
                PORTAL_ADMIN_EMAIL)    [[ -n "$value" ]] && PORTAL_ADMIN_EMAIL="$value" ;;
                PORTAL_ADMIN_FN)       [[ -n "$value" ]] && PORTAL_ADMIN_FN="$value" ;;
                PORTAL_ADMIN_LN)       [[ -n "$value" ]] && PORTAL_ADMIN_LN="$value" ;;
                PORTAL_ADMIN_QI)       [[ -n "$value" ]] && PORTAL_ADMIN_QI="$value" ;;
                PORTAL_ADMIN_QA)       [[ -n "$value" ]] && PORTAL_ADMIN_QA="$value" ;;
                MIN_RAM_MB)            [[ -n "$value" ]] && MIN_RAM_MB="$value" ;;
                MIN_CPU_CORES)         [[ -n "$value" ]] && MIN_CPU_CORES="$value" ;;
                MIN_DISK_HOME_GB)      [[ -n "$value" ]] && MIN_DISK_HOME_GB="$value" ;;
                MIN_DISK_INSTALL_GB)   [[ -n "$value" ]] && MIN_DISK_INSTALL_GB="$value" ;;
            esac
        done < "$conf_path"
        echo "[SUCCESS] 配置文件已加载"
    fi
}

load_config_from_file

#==============================================================================
# 再次解析命令行参数（覆盖配置文件）
#==============================================================================
for arg in "$@"; do
    [[ "$arg" =~ ^--gs-user= ]] && GS_USER="${arg#*=}"
    [[ "$arg" =~ ^--gs-base= ]] && GS_BASE="${arg#*=}"
done

#==============================================================================
# 常量定义（基于配置后的变量）
#==============================================================================
readonly LOG_FILE="/var/log/geoscene_$(date +%Y%m%d_%H%M%S).log"
readonly SILENT_FLAGS="-m silent -l yes"
readonly STATE_FILE="/var/log/.geoscene_install_state"
readonly LIMITS_CONF="/etc/security/limits.d/99-geoscene.conf"
REQUIRED_PORTS=("$SERVER_PORT" "$PORTAL_PORT" "$DATASTORE_PORT" "9876" "9877")

#==============================================================================
# 动态调整 GS_HOME 和 GS_BASE（如果只修改了 GS_USER）
#==============================================================================
if [[ "$GS_HOME" == "/home/geoscene" && "$GS_USER" != "geoscene" ]]; then
    GS_HOME="/home/$GS_USER"
fi
if [[ "$GS_BASE" == "/home/geoscene/geoscene" && "$GS_USER" != "geoscene" ]]; then
    GS_BASE="$GS_HOME/geoscene"
fi

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
log_dry()     { log "DRY-RUN" "36" "$1"; }

print_task_header() {
    local title="$1"
    echo ""
    echo -e "\033[44;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[44;37m  $title\033[0m"
    echo -e "\033[44;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
}

print_subtask() {
    local title="$1"
    echo -e "\033[36m  ▸ $title\033[0m"
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

print_subtask_error() {
    local title="$1"
    echo -e "\033[31m  ✗ $title\033[0m"
    log_error "$title"
}

detect_host_ip() {
    local ip=""
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    if [[ -z "$ip" ]]; then
        ip=$(ip -4 addr show 2>/dev/null | awk '/inet /{print $2}' | grep -vE '^127\.' | head -1 | cut -d/ -f1)
    fi
    echo "${ip:-127.0.0.1}"
}

get_host_ip() {
    if [[ -z "$HOST_IP" ]]; then
        HOST_IP=$(detect_host_ip)
    fi
    echo "$HOST_IP"
}

log_host_ip() {
    if [[ -z "$HOST_IP" ]]; then
        HOST_IP=$(detect_host_ip)
        log_info "检测到主机 IP: $HOST_IP"
    fi
    echo "$HOST_IP"
}

trap 'find "$SCRIPT_DIR" -maxdepth 1 -type d -name "geoscene_inst_*" -exec rm -rf {} + 2>/dev/null || true' EXIT

gs_install_dir() { echo "$GS_BASE/$1"; }
is_installed()   { [[ -f "$(gs_install_dir "$1")/.geoscene_installed" ]]; }

find_tool() {
    local comp="$1" tool_name="$2"
    local search_paths=(
        "$GS_BASE/$comp/tools/$tool_name/$tool_name"
        "$GS_BASE/$comp/tools/$tool_name"
        "$GS_BASE/$comp/tools/bin/$tool_name"
        "$GS_BASE/$comp/bin/$tool_name"
        "$GS_BASE/$comp/$tool_name"
    )
    for path in "${search_paths[@]}"; do
        if [[ -f "$path" && -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

declare -gA FOUND_INSTALLERS=()
declare -gA FOUND_LICENSES=()
declare -ga COMPONENT_QUEUE=()

to_lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

scan_workspace() {
    FOUND_INSTALLERS=(); FOUND_LICENSES=(); COMPONENT_QUEUE=()

    for f in "$SCRIPT_DIR"/*; do
        [[ -f "$f" ]] || continue
        local base="${f##*/}"
        local lower; lower=$(to_lower "$base")

        if [[ "$base" == *.tar.gz || "$base" == *.tgz ]]; then
            [[ "$lower" == *server* ]] && { FOUND_INSTALLERS[server]="$f"; COMPONENT_QUEUE+=(server); }
            [[ "$lower" == *portal* ]] && { FOUND_INSTALLERS[portal]="$f"; COMPONENT_QUEUE+=(portal); }
            [[ "$lower" == *data* ]] && { FOUND_INSTALLERS[datastore]="$f"; COMPONENT_QUEUE+=(datastore); }
        elif [[ "$base" == *.prvc || "$base" == *.json || "$base" == *.ecl || "$base" == *.lic || "$base" == *.ecp ]]; then
            if [[ "$lower" == *portal* || "$lower" == *enterprise*portal* ]]; then
                FOUND_LICENSES[portal]="$f"
            elif [[ "$lower" == *server* || "$base" == *.prvc || "$base" == *.ecp ]]; then
                FOUND_LICENSES[server]="$f"
            elif [[ "$base" == *.json && ( "$lower" == *enterprise* || "$lower" == *portal* ) ]]; then
                FOUND_LICENSES[portal]="$f"
            fi
        fi
    done

    if [[ ${#COMPONENT_QUEUE[@]} -eq 0 ]]; then
        log_error "未在 $SCRIPT_DIR 找到任何 GeoScene 安装包 (.tar.gz / .tgz)"
        exit 1
    fi

    log_info "发现组件: ${COMPONENT_QUEUE[*]}"
    for comp in "${COMPONENT_QUEUE[@]}"; do
        local pkg_name=$(basename "${FOUND_INSTALLERS[$comp]}")
        local lic_status="无授权文件"
        if [[ "$comp" == "datastore" ]]; then
            lic_status="无需授权文件"
        elif [[ -n "${FOUND_LICENSES[$comp]+_}" ]]; then
            lic_status="授权文件: $(basename "${FOUND_LICENSES[$comp]}")"
        fi
        log_info "  [$comp]  $pkg_name  |  $lic_status"
    done
    
    if [[ "$SKIP_CONFIG" == false ]]; then
        if [[ -z "${FOUND_LICENSES[server]+_}" ]]; then
            log_warn "缺少 Server 授权文件，自动化配置将无法执行"
        fi
        if [[ -z "${FOUND_LICENSES[portal]+_}" ]]; then
            log_warn "缺少 Portal 授权文件，自动化配置将无法执行"
        fi
    fi
}

check_prerequisites() {
    [[ $EUID -ne 0 ]] && { log_error "需 root 权限执行"; exit 1; }

    local ram_mb cpu_cores
    ram_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
    cpu_cores=$(nproc)
    (( ram_mb   < MIN_RAM_MB )) && log_warn "内存 ${ram_mb}MB < ${MIN_RAM_MB}MB，仅建议测试环境"
    (( cpu_cores < MIN_CPU_CORES )) && log_warn "CPU ${cpu_cores} 核 < ${MIN_CPU_CORES}核，可能影响性能"

    _check_disk() {
        local path="$1" req_gb="$2" check="$1"
        while [[ ! -e "$check" && "$check" != "/" ]]; do check="$(dirname "$check")"; done
        local avail_kb; avail_kb=$(df -k "$check" 2>/dev/null | awk 'NR==2{print $4}')
        [[ -z "$avail_kb" || ! "$avail_kb" =~ ^[0-9]+$ ]] && { log_error "无法读取 $check 磁盘空间"; return 1; }
        local avail_gb=$(( avail_kb / 1048576 ))
        (( avail_gb < req_gb )) && { log_error "$path 可用 ${avail_gb}GB < 要求 ${req_gb}GB"; return 1; }
        log_info "磁盘 $path: 可用 ${avail_gb}GB"
    }
    _check_disk "$GS_HOME" "$MIN_DISK_HOME_GB" || exit 1
    _check_disk "$SCRIPT_DIR" "$MIN_DISK_INSTALL_GB" || exit 1

    local conflict=false
    for port in "${REQUIRED_PORTS[@]}"; do
        if ss -tulnH 2>/dev/null | awk '{print $5}' | grep -qE ":${port}$" || \
           netstat -tuln 2>/dev/null | grep -qE ":${port}[[:space:]]"; then
            log_error "端口 $port 已占用"
            conflict=true
        fi
    done
    [[ "$conflict" == true ]] && { log_error "端口冲突，中止安装"; exit 1; }

    log_success "前置校验通过  (CPU=${cpu_cores}核 RAM=${ram_mb}MB)"
}

setup_system() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 系统配置"; return 0; }

    if ! getent group "$GS_GROUP" &>/dev/null; then groupadd "$GS_GROUP"; fi
    if ! id "$GS_USER" &>/dev/null; then
        useradd -m -s /bin/bash -g "$GS_GROUP" -d "$GS_HOME" "$GS_USER"
        log_info "用户 $GS_USER 已创建 → $GS_HOME"
    fi

    cat > "$LIMITS_CONF" <<EOF
# GeoScene Enterprise - managed by installer
$GS_USER soft nofile 65536
$GS_USER hard nofile 65536
$GS_USER soft nproc  32768
$GS_USER hard nproc  32768
EOF

    mkdir -p "$GS_BASE"
    chown "$GS_USER:$GS_GROUP" "$GS_BASE"

    if command -v firewall-cmd &>/dev/null; then
        for p in "${REQUIRED_PORTS[@]}"; do
            firewall-cmd --permanent --add-port="${p}/tcp" &>/dev/null || true
        done
        firewall-cmd --reload &>/dev/null || true
        log_info "防火墙已开放端口: ${REQUIRED_PORTS[*]}"
    fi

    echo "INSTALLED=$(date '+%Y-%m-%d %H:%M:%S')" > "$STATE_FILE"
    log_success "系统配置完成"
}

install_component() {
    local comp="$1" tarball="$2"

    if is_installed "$comp"; then
        log_info "$comp 已安装，跳过"
        return 0
    fi

    local size; size=$(du -sh "$tarball" 2>/dev/null | cut -f1 || echo '?')
    print_task_header "安装 $comp ($size)"
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 安装 $comp"; return 0; }

    local extract_dir="$SCRIPT_DIR/geoscene_inst_${comp}"
    rm -rf "$extract_dir"; mkdir -p "$extract_dir"

    print_subtask "解压安装包..."
    if ! tar -xzf "$tarball" -C "$extract_dir" 2>&1 | tee -a "$LOG_FILE"; then
        print_subtask_error "解压失败: $(basename "$tarball")"
        rm -rf "$extract_dir"; return 1
    fi
    print_subtask_success "解压完成"

    chown -R "$GS_USER:$GS_GROUP" "$extract_dir"

    local installer
    installer=$(find "$extract_dir" -maxdepth 3 -type f \
        \( -iname "Setup" -o -iname "setup" -o -iname "setup.sh" \) \
        -executable 2>/dev/null | head -n1)
    [[ -z "$installer" ]] && {
        print_subtask_error "未找到安装入口 (Setup/setup/setup.sh)"
        rm -rf "$extract_dir"; return 1
    }

    print_subtask "执行静默安装..."
    local rc=0
    runuser -u "$GS_USER" -- bash -c \
        "cd '$(dirname "$installer")' && './$(basename "$installer")' $SILENT_FLAGS" \
        2>&1 | tee -a "$LOG_FILE" || rc=${PIPESTATUS[0]}

    rm -rf "$extract_dir"

    if [[ $rc -eq 0 ]]; then
        touch "$(gs_install_dir "$comp")/.geoscene_installed"
        print_subtask_success "$comp 安装完成"
    else
        print_subtask_error "$comp 安装失败 (exit $rc)"
        return 1
    fi
}

copy_license_files() {
    local copied=0
    
    for comp in "${COMPONENT_QUEUE[@]}"; do
        [[ "$comp" == "datastore" ]] && continue
        
        if [[ -n "${FOUND_LICENSES[$comp]+_}" ]]; then
            [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 复制 $comp 授权文件"; continue; }
            
            local lic_file="${FOUND_LICENSES[$comp]}"
            local lic_name=$(basename "$lic_file")
            local lic_dest="$GS_HOME/$lic_name"
            
            cp "$lic_file" "$lic_dest" 2>/dev/null || true
            chown "$GS_USER:$GS_GROUP" "$lic_dest" 2>/dev/null || true
            chmod 644 "$lic_dest" 2>/dev/null || true
            
            print_subtask "复制 $comp 授权文件: $lic_dest"
            (( copied++ )) || true
            
            case "$comp" in
                server)
                    local server_lic_dir="$GS_BASE/server/usr"
                    if [[ -d "$server_lic_dir" ]]; then
                        cp "$lic_dest" "$server_lic_dir/$lic_name" 2>/dev/null || true
                        chown "$GS_USER:$GS_GROUP" "$server_lic_dir/$lic_name" 2>/dev/null || true
                        print_subtask_success "Server usr 目录副本"
                    fi
                    ;;
                portal)
                    local portal_lic_dir="$GS_BASE/portal/usr"
                    if [[ -d "$portal_lic_dir" ]]; then
                        cp "$lic_dest" "$portal_lic_dir/$lic_name" 2>/dev/null || true
                        chown "$GS_USER:$GS_GROUP" "$portal_lic_dir/$lic_name" 2>/dev/null || true
                        print_subtask_success "Portal usr 目录副本"
                    fi
                    ;;
            esac
        fi
    done
    
    if [[ $copied -gt 0 ]]; then
        print_subtask_success "授权文件复制完成 ($copied 个)"
    fi
}

start_server() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 启动 Server"; return 0; }
    
    local start_script="$GS_BASE/server/startserver.sh"
    if [[ ! -f "$start_script" ]]; then
        print_subtask_warn "未找到 Server 启动脚本"
        return 1
    fi
    
    if check_server_running; then
        print_subtask_success "Server 已在运行"
        return 0
    fi
    
    print_subtask "启动 GeoScene Server..."
    runuser -u "$GS_USER" -- "$start_script" 2>&1 | tee -a "$LOG_FILE" || true
    
    local max_wait=120 elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        if check_server_running; then
            print_subtask_success "Server 已就绪"
            return 0
        fi
        sleep 5; elapsed=$((elapsed + 5))
        log_info "等待 Server 就绪... ($elapsed/$max_wait 秒)"
    done
    print_subtask_warn "Server 启动超时（进程可能仍在运行）"
    return 1
}

check_server_running() {
    local server_proc="$GS_BASE/server"
    if pgrep -f "geoscene.*server" &>/dev/null || \
       [[ -f "$server_proc/usr/logs/server.pid" ]] || \
       curl -sk "https://$(get_host_ip):${SERVER_PORT}/geoscene/rest/info" &>/dev/null; then
        return 0
    fi
    return 1
}

check_server_initialized() {
    local host_ip=$(get_host_ip)
    local token=""
    
    token=$(curl -sk -X POST "https://${host_ip}:${SERVER_PORT}/geoscene/admin/generateToken" \
        -d "username=$SITE_ADMIN_USER" \
        -d "password=$SITE_ADMIN_PASS" \
        -d "client=requestip" \
        -d "f=json" 2>/dev/null | grep -oP '"token":"[^"]+' | cut -d'"' -f4)
    
    [[ -n "$token" ]] && return 0
    return 1
}

check_datastore_ready() {
    local host_ip=$(get_host_ip)
    local response
    response=$(curl -sk "https://${host_ip}:${DATASTORE_PORT}/geoscene/datastoreadmin/configure?f=json" 2>/dev/null)
    
    if echo "$response" | grep -qiE '"status"|configure' || curl -sk "https://${host_ip}:${DATASTORE_PORT}/geoscene/datastore" &>/dev/null; then
        return 0
    fi
    return 1
}

authorize_server() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: Server 授权"; return 0; }
    [[ "$SKIP_CONFIG" == true ]] && { log_info "跳过自动化配置"; return 0; }
    
    if [[ -z "${FOUND_LICENSES[server]+_}" ]]; then
        print_subtask_warn "缺少 Server 授权文件，请浏览器手动授权"
        return 1
    fi
    
    local lic_file="${FOUND_LICENSES[server]}"
    local lic_name=$(basename "$lic_file")
    local lic_dest="$GS_HOME/$lic_name"
    
    print_task_header "Server 授权"
    print_subtask "授权文件: $lic_name"
    
    local auth_tool="$GS_BASE/server/tools/authorizeSoftware"
    if [[ ! -f "$auth_tool" ]]; then
        print_subtask_error "未找到 authorizeSoftware 工具"
        print_subtask_warn "请浏览器访问: https://$(get_host_ip):${SERVER_PORT}/geoscene/manager 手动授权"
        return 1
    fi
    
    print_subtask "执行授权命令..."
    local rc=0
    local output
    output=$(runuser -u "$GS_USER" -- "$auth_tool" -f "$lic_dest" 2>&1) || rc=$?
    echo "$output" | tee -a "$LOG_FILE"
    
    if [[ $rc -eq 0 ]]; then
        print_subtask_success "Server 授权成功"
        sleep 10
        return 0
    else
        print_subtask_error "Server 授权失败 (exit $rc)"
        print_subtask_warn "请浏览器访问: https://$(get_host_ip):${SERVER_PORT}/geoscene/manager 手动授权"
        return 1
    fi
}

create_server_site() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 创建 Server 站点"; return 0; }
    [[ "$SKIP_CONFIG" == true ]] && { log_info "跳过自动化配置"; return 0; }
    
    print_task_header "创建 Server 站点"
    
    if check_server_initialized; then
        print_subtask_success "Server 站点已存在"
        return 0
    fi
    
    local site_tool="$GS_BASE/server/tools/createsite/createsite.sh"
    if [[ ! -f "$site_tool" ]]; then
        print_subtask_error "未找到 createsite.sh 工具"
        print_subtask_warn "请浏览器访问: https://$(get_host_ip):${SERVER_PORT}/geoscene/manager 手动创建站点"
        return 1
    fi
    
    local directories="$GS_BASE/server/usr/directories"
    local config_store="$GS_BASE/server/usr/config-store"
    mkdir -p "$directories" "$config_store"
    chown -R "$GS_USER:$GS_GROUP" "$directories" "$config_store"
    
    print_subtask "执行站点创建命令..."
    print_subtask "用户: $SITE_ADMIN_USER | 密码: $SITE_ADMIN_PASS"
    
    local rc=0
    local output
    output=$(runuser -u "$GS_USER" -- "$site_tool" \
        -u "$SITE_ADMIN_USER" \
        -p "$SITE_ADMIN_PASS" \
        -d "$directories" \
        -c "$config_store" 2>&1) || rc=$?
    echo "$output" | tee -a "$LOG_FILE"
    
    if [[ $rc -eq 0 ]]; then
        print_subtask_success "Server 站点创建成功"
        
        print_subtask "等待站点服务初始化..."
        local site_wait_max=12 site_wait_count=0
        while [[ $site_wait_count -lt $site_wait_max ]]; do
            if check_server_initialized; then
                print_subtask_success "Server 站点已就绪"
                break
            fi
            site_wait_count=$((site_wait_count + 1))
            [[ $site_wait_count -lt $site_wait_max ]] && {
                log_info "等待站点初始化... ($site_wait_count/$site_wait_max)"
                sleep 10
            }
        done
        
        sleep 30
        return 0
    else
        print_subtask_error "Server 站点创建失败 (exit $rc)"
        print_subtask_warn "请浏览器访问: https://$(get_host_ip):${SERVER_PORT}/geoscene/manager 手动创建站点"
        return 1
    fi
}

start_portal() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 启动 Portal"; return 0; }
    
    local start_script="$GS_BASE/portal/startportal.sh"
    if [[ ! -f "$start_script" ]]; then
        print_subtask_warn "未找到 Portal 启动脚本"
        return 1
    fi
    
    if check_portal_running; then
        print_subtask_success "Portal 已在运行"
        return 0
    fi
    
    print_subtask "启动 GeoScene Portal..."
    runuser -u "$GS_USER" -- "$start_script" 2>&1 | tee -a "$LOG_FILE" || true
    
    local max_wait=180 elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        if check_portal_running; then
            print_subtask_success "Portal 已就绪"
            return 0
        fi
        sleep 10; elapsed=$((elapsed + 10))
        log_info "等待 Portal 就绪... ($elapsed/$max_wait 秒)"
    done
    print_subtask_warn "Portal 启动超时（进程可能仍在运行）"
    return 1
}

check_portal_initialized() {
    local host_ip=$(get_host_ip)
    local response
    response=$(curl -sk "https://${host_ip}:${PORTAL_PORT}/geoscene/sharing/rest/portals/self?f=json" 2>/dev/null)
    
    if echo "$response" | grep -qi '"id"' && ! echo "$response" | grep -qi "not initialized"; then
        return 0
    fi
    return 1
}

check_portal_running() {
    if pgrep -f "geoscene.*portal" &>/dev/null || \
       [[ -f "$GS_BASE/portal/usr/logs/portal.pid" ]] || \
       curl -sk "https://$(get_host_ip):${PORTAL_PORT}/geoscene/rest/info" &>/dev/null; then
        return 0
    fi
    return 1
}

create_portal() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 创建 Portal 门户"; return 0; }
    [[ "$SKIP_CONFIG" == true ]] && { log_info "跳过自动化配置"; return 0; }
    
    if [[ -z "${FOUND_LICENSES[portal]+_}" ]]; then
        print_subtask_warn "缺少 Portal 授权文件，请浏览器手动创建门户"
        return 1
    fi
    
    print_task_header "创建 Portal 门户"
    
    local portal_tool="$GS_BASE/portal/tools/createportal/createportal.sh"
    if [[ ! -f "$portal_tool" ]]; then
        print_subtask_error "未找到 createportal.sh 工具"
        print_subtask_warn "请浏览器访问: https://$(get_host_ip):${PORTAL_PORT}/geoscene/home 手动创建门户"
        return 1
    fi
    
    local lic_file="${FOUND_LICENSES[portal]}"
    local lic_name=$(basename "$lic_file")
    local lic_dest="$GS_HOME/$lic_name"
    
    print_subtask "授权文件: $lic_name"
    
    local portal_content="$GS_BASE/portal/usr/portal-content"
    mkdir -p "$portal_content"
    chown -R "$GS_USER:$GS_GROUP" "$portal_content"
    chmod 755 "$portal_content"
    
    print_subtask "执行门户创建命令..."
    print_subtask "用户: $PORTAL_ADMIN_USER | 密码: $PORTAL_ADMIN_PASS | 邮箱: $PORTAL_ADMIN_EMAIL"
    
    local max_retries=3 retry_count=0 retry_interval=30 rc=0 output
    
    while [[ $retry_count -lt $max_retries ]]; do
        rc=0
        output=$(runuser -u "$GS_USER" -- "$portal_tool" \
            -fn "$PORTAL_ADMIN_FN" \
            -ln "$PORTAL_ADMIN_LN" \
            -u "$PORTAL_ADMIN_USER" \
            -p "$PORTAL_ADMIN_PASS" \
            -e "$PORTAL_ADMIN_EMAIL" \
            -qi "$PORTAL_ADMIN_QI" \
            -qa "$PORTAL_ADMIN_QA" \
            -d "$portal_content" \
            -lf "$lic_dest" 2>&1) || rc=$?
        echo "$output" | tee -a "$LOG_FILE"
        
        if [[ $rc -eq 0 ]] && ! echo "$output" | grep -qiE "failed|error|index service configuration failed"; then
            print_subtask_success "Portal 门户创建成功（授权已导入）"
            sleep 30
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            print_subtask_warn "Portal 创建失败或出现错误，等待 ${retry_interval}s 后重试 ($retry_count/$max_retries)"
            sleep $retry_interval
            
            print_subtask "重启 Portal 服务..."
            runuser -u "$GS_USER" -- "$GS_BASE/portal/stopportal.sh" 2>/dev/null || true
            sleep 10
            runuser -u "$GS_USER" -- "$GS_BASE/portal/startportal.sh" 2>&1 | tee -a "$LOG_FILE" || true
            sleep 60
            
            print_subtask "重新尝试创建门户..."
        fi
    done
    
    if echo "$output" | grep -qi "index service configuration failed"; then
        print_subtask_error "Portal Index Service 配置失败"
        print_subtask_warn "Portal 可能已部分创建，请浏览器访问检查: https://$(get_host_ip):${PORTAL_PORT}/geoscene/home"
    else
        print_subtask_error "Portal 门户创建失败 (exit $rc)"
        print_subtask_warn "请浏览器访问: https://$(get_host_ip):${PORTAL_PORT}/geoscene/home 手动创建门户"
    fi
    return 1
}

update_portal_webcontext() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 更新 Portal WebContextURL"; return 0; }
    [[ "$SKIP_CONFIG" == true ]] && { log_info "跳过自动化配置"; return 0; }
    
    print_task_header "更新 Portal WebContextURL"
    
    local host_ip=$(get_host_ip)
    local portal_token=""
    
    print_subtask "等待 Portal 完全就绪..."
    sleep 30
    
    print_subtask "获取 Portal Token..."
    local max_token_retries=12 token_retry_interval=10 token_retry_count=0
    
    while [[ $token_retry_count -lt $max_token_retries ]]; do
        portal_token=$(curl -sk -X POST "https://${host_ip}:${PORTAL_PORT}/geoscene/sharing/rest/generateToken" \
            -d "username=$PORTAL_ADMIN_USER" \
            -d "password=$PORTAL_ADMIN_PASS" \
            -d "client=requestip" \
            -d "f=json" 2>/dev/null | grep -oP '"token":"[^"]+' | cut -d'"' -f4)
        
        if [[ -n "$portal_token" ]]; then
            break
        fi
        
        token_retry_count=$((token_retry_count + 1))
        [[ $token_retry_count -lt $max_token_retries ]] && {
            log_info "等待 Portal Token... ($token_retry_count/$max_token_retries)"
            sleep $token_retry_interval
        }
    done
    
    if [[ -z "$portal_token" ]]; then
        print_subtask_warn "无法获取 Portal Token，跳过 WebContextURL 更新"
        print_subtask_warn "请手动在 Portal Admin 中更新 Web Context URL"
        return 1
    fi
    print_subtask_success "Token 获取成功"
    
    local web_context_url="https://${host_ip}:${PORTAL_PORT}/geoscene"
    print_subtask "设置 WebContextURL: $web_context_url"
    
    local rc=0
    local output
    output=$(curl -sk -X POST "https://${host_ip}:${PORTAL_PORT}/geoscene/portaladmin/system/updateWebContextURL" \
        -d "webContextURL=$web_context_url" \
        -d "token=$portal_token" \
        -d "f=json" 2>&1) || rc=$?
    echo "$output" | tee -a "$LOG_FILE"
    
    if [[ $rc -eq 0 ]]; then
        print_subtask_success "Portal WebContextURL 已更新: $web_context_url"
        
        print_subtask "重启 Portal..."
        runuser -u "$GS_USER" -- "$GS_BASE/portal/stopportal.sh" 2>/dev/null || true
        sleep 10
        runuser -u "$GS_USER" -- "$GS_BASE/portal/startportal.sh" 2>&1 | tee -a "$LOG_FILE" || true
        sleep 30
        
        print_subtask_success "Portal 已重启，WebContextURL 配置生效"
        return 0
    else
        print_subtask_error "Portal WebContextURL 更新失败"
        print_subtask_warn "请手动在 Portal Admin 中更新 Web Context URL"
        return 1
    fi
}

start_datastore() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 启动 DataStore"; return 0; }
    
    local start_script="$GS_BASE/datastore/startdatastore.sh"
    if [[ ! -f "$start_script" ]]; then
        print_subtask_warn "未找到 DataStore 启动脚本"
        return 1
    fi
    
    if check_datastore_running; then
        print_subtask_success "DataStore 已在运行"
        return 0
    fi
    
    print_subtask "启动 GeoScene DataStore..."
    runuser -u "$GS_USER" -- "$start_script" 2>&1 | tee -a "$LOG_FILE" || true
    
    local max_wait=120 elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        if check_datastore_running; then
            print_subtask_success "DataStore 已就绪"
            return 0
        fi
        sleep 5; elapsed=$((elapsed + 5))
        log_info "等待 DataStore 就绪... ($elapsed/$max_wait 秒)"
    done
    print_subtask_warn "DataStore 启动超时（进程可能仍在运行）"
    return 1
}

check_datastore_running() {
    if pgrep -f "geoscene.*datastore" &>/dev/null || \
       [[ -f "$GS_BASE/datastore/usr/logs/datastore.pid" ]] || \
       curl -sk "https://$(get_host_ip):${DATASTORE_PORT}/geoscene/datastore" &>/dev/null; then
        return 0
    fi
    return 1
}

ensure_publishing_tools() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 确保 PublishingTools 启动"; return 0; }
    [[ "$SKIP_CONFIG" == true ]] && { log_info "跳过自动化配置"; return 0; }
    
    print_subtask "检查并启动 PublishingTools 服务..."
    
    local host_ip=$(get_host_ip)
    local token=""
    local max_retries=12 retry_interval=10 retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        token=$(curl -sk -X POST "https://${host_ip}:${SERVER_PORT}/geoscene/admin/generateToken" \
            -d "username=$SITE_ADMIN_USER" \
            -d "password=$SITE_ADMIN_PASS" \
            -d "client=requestip" \
            -d "f=json" 2>/dev/null | grep -oP '"token":"[^"]+' | cut -d'"' -f4)
        
        if [[ -n "$token" ]]; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        [[ $retry_count -lt $max_retries ]] && {
            log_info "等待 Server Token... ($retry_count/$max_retries)"
            sleep $retry_interval
        }
    done
    
    if [[ -z "$token" ]]; then
        print_subtask_warn "无法获取 Server Token，跳过 PublishingTools 检查"
        return 1
    fi
    
    local status_url="https://${host_ip}:${SERVER_PORT}/geoscene/admin/services/System/PublishingTools.GPServer/status"
    local start_url="https://${host_ip}:${SERVER_PORT}/geoscene/admin/services/System/PublishingTools.GPServer/start"
    
    retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        local status
        status=$(curl -sk "${status_url}?f=json&token=$token" 2>/dev/null)
        
        if echo "$status" | grep -qi '"configuredState"[[:space:]]*:[[:space:]]*"started"'; then
            print_subtask_success "PublishingTools 已运行"
            return 0
        fi
        
        if echo "$status" | grep -qi "stopped"; then
            print_subtask "启动 PublishingTools 服务..."
            curl -sk -X POST "${start_url}?f=json&token=$token" &>/dev/null
        fi
        
        retry_count=$((retry_count + 1))
        [[ $retry_count -lt $max_retries ]] && {
            log_info "等待 PublishingTools 就绪... ($retry_count/$max_retries)"
            sleep $retry_interval
        }
    done
    
    print_subtask_warn "PublishingTools 未能在规定时间内就绪"
    return 1
}

configure_datastore() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 配置 DataStore"; return 0; }
    [[ "$SKIP_CONFIG" == true ]] && { log_info "跳过自动化配置"; return 0; }
    
    print_task_header "配置 DataStore"
    
    local ds_tool="$GS_BASE/datastore/tools/configuredatastore.sh"
    if [[ ! -f "$ds_tool" ]]; then
        print_subtask_error "未找到 configuredatastore.sh 工具"
        print_subtask_warn "请浏览器访问: https://${host_ip}:${DATASTORE_PORT}/geoscene/datastore 手动配置"
        return 1
    fi
    
    local host_ip=$(get_host_ip)
    
    if ! check_server_initialized; then
        print_subtask_error "Server 站点未初始化或 Token 获取失败"
        print_subtask_warn "请先确认 Server 站点创建成功"
        return 1
    fi
    
    print_subtask "确保 PublishingTools 已启动..."
    if ! ensure_publishing_tools; then
        print_subtask_warn "PublishingTools 未就绪，可能影响 DataStore 配置"
    fi
    
    local ds_data="$GS_BASE/datastore/usr/datastore"
    mkdir -p "$ds_data"
    chown -R "$GS_USER:$GS_GROUP" "$ds_data"
    
    print_subtask "等待 DataStore 配置服务就绪..."
    local ds_ready_max=12 ds_ready_count=0
    while [[ $ds_ready_count -lt $ds_ready_max ]]; do
        if check_datastore_ready; then
            break
        fi
        ds_ready_count=$((ds_ready_count + 1))
        [[ $ds_ready_count -lt $ds_ready_max ]] && {
            log_info "等待 DataStore 配置接口... ($ds_ready_count/$ds_ready_max)"
            sleep 10
        }
    done
    
    print_subtask "执行 DataStore 配置命令..."
    print_subtask "连接 Server: https://${host_ip}:${SERVER_PORT}/geoscene/admin"
    print_subtask "用户: $SITE_ADMIN_USER | 密码: $SITE_ADMIN_PASS"
    print_subtask "存储类型: relational, spatiotemporal"
    
    local max_retries=3 retry_count=0 retry_interval=30 rc=0 output
    
    while [[ $retry_count -lt $max_retries ]]; do
        rc=0
        output=$(runuser -u "$GS_USER" -- "$ds_tool" \
            "https://${host_ip}:${SERVER_PORT}/geoscene/admin" \
            "$SITE_ADMIN_USER" \
            "$SITE_ADMIN_PASS" \
            "$ds_data" \
            --stores relational,spatiotemporal 2>&1) || rc=$?
        echo "$output" | tee -a "$LOG_FILE"
        
        if [[ $rc -eq 0 ]]; then
            print_subtask_success "DataStore 配置成功"
            return 0
        fi
        
        if echo "$output" | grep -qiE "unable to configure|attempt to configure data store failed"; then
            print_subtask_warn "检测到配置失败错误信息"
        fi
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            print_subtask_warn "DataStore 配置失败，等待 ${retry_interval}s 后重试 ($retry_count/$max_retries)"
            sleep $retry_interval
            print_subtask "重新尝试配置..."
            ensure_publishing_tools || true
            sleep 20
        fi
    done
    
    print_subtask_error "DataStore 配置失败 (exit $rc)"
    print_subtask_warn "请浏览器访问: https://${host_ip}:${DATASTORE_PORT}/geoscene/datastore 手动配置"
    return 1
}

print_summary() {
    local host_ip; host_ip=$(get_host_ip)
    local installed_comps=()
    for comp in server portal datastore; do
        is_installed "$comp" && installed_comps+=("$comp")
    done
    
    local server_lic=""
    local portal_lic=""
    [[ -n "${FOUND_LICENSES[server]+_}" ]] && server_lic=$(basename "${FOUND_LICENSES[server]}")
    [[ -n "${FOUND_LICENSES[portal]+_}" ]] && portal_lic=$(basename "${FOUND_LICENSES[portal]}")

    local config_status=""
    if [[ "$SKIP_CONFIG" == true ]]; then
        config_status="已跳过自动化配置"
    else
        config_status="已执行自动化配置"
    fi

    echo ""
    echo -e "\033[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  GeoScene Enterprise 安装完成"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    echo "  安装用户:    $GS_USER"
    echo "  安装目录:    $GS_BASE"
    echo "  主机 IP:     $host_ip"
    echo "  日志文件:    $LOG_FILE"
    echo "  配置状态:    $config_status"
    echo ""
    echo "  已安装组件:"
    for comp in "${installed_comps[@]}"; do
        echo "    ✅ $comp  →  $(gs_install_dir "$comp")"
    done
    echo ""
    
    echo "  访问地址 (使用实际 IP):"
    is_installed server    && echo "    Server Manager:  https://${host_ip}:${SERVER_PORT}/geoscene/manager"
    is_installed server    && echo "    Server REST:     https://${host_ip}:${SERVER_PORT}/geoscene/rest/services"
    is_installed portal    && echo "    Portal:          https://${host_ip}:${PORTAL_PORT}/geoscene/home"
    is_installed portal    && echo "    Portal Admin:    https://${host_ip}:${PORTAL_PORT}/geoscene/portaladmin"
    is_installed datastore && echo "    DataStore:       https://${host_ip}:${DATASTORE_PORT}/geoscene/datastore"
    echo ""
    
    if [[ "$SKIP_CONFIG" == true ]]; then
        echo -e "\033[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "\033[36m  手动配置步骤 (请按顺序执行):\033[0m"
        echo -e "\033[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo ""
        
        if is_installed server; then
            echo -e "\033[33m  步骤 1: Server 授权\033[0m"
            if [[ -n "$server_lic" ]]; then
                echo "    命令行: runuser -u $GS_USER -- $GS_BASE/server/tools/authorizeSoftware -f $GS_HOME/$server_lic"
            else
                echo "    浏览器: https://${host_ip}:${SERVER_PORT}/geoscene/manager"
            fi
            echo ""
            
            echo -e "\033[33m  步骤 2: 创建 Server 站点\033[0m"
            echo "    命令行: runuser -u $GS_USER -- $GS_BASE/server/tools/createsite/createsite.sh"
            echo "    浏览器: https://${host_ip}:${SERVER_PORT}/geoscene/manager"
            echo ""
        fi
        
        if is_installed portal; then
            echo -e "\033[33m  步骤 3: 创建 Portal 门户\033[0m"
            if [[ -n "$portal_lic" ]]; then
                echo "    命令行: runuser -u $GS_USER -- $GS_BASE/portal/tools/createportal/createportal.sh -fn Admin -ln User -u portaladmin -p YourPassword123 -e admin@example.com -qi 1 -qa Beijing -d $GS_BASE/portal/usr/portal-content -lf $GS_HOME/$portal_lic"
            fi
            echo "    浏览器: https://${host_ip}:${PORTAL_PORT}/geoscene/home"
            echo ""
        fi
        
        if is_installed datastore; then
            echo -e "\033[33m  步骤 4: 配置 DataStore\033[0m"
            echo "    命令行: runuser -u $GS_USER -- $GS_BASE/datastore/tools/configuredatastore.sh https://${host_ip}:${SERVER_PORT}/geoscene/admin siteadmin YourPassword123 $GS_BASE/datastore/usr/datastore --stores relational,spatiotemporal"
            echo "    浏览器: https://${host_ip}:${DATASTORE_PORT}/geoscene/datastore"
            echo ""
        fi
    else
        echo -e "\033[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "\033[36m  管理员账户信息:\033[0m"
        echo -e "\033[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo ""
        echo "  Server 管理员:"
        echo "    用户名: $SITE_ADMIN_USER"
        echo "    密码:   $SITE_ADMIN_PASS"
        echo ""
        echo "  Portal 管理员:"
        echo "    用户名: $PORTAL_ADMIN_USER"
        echo "    密码:   $PORTAL_ADMIN_PASS"
        echo "    邮箱:   $PORTAL_ADMIN_EMAIL"
        echo ""
        
        echo -e "\033[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "\033[36m  如果自动化配置失败，请浏览器手动处理:\033[0m"
        echo -e "\033[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo ""
        echo "  Server 授权/站点: https://${host_ip}:${SERVER_PORT}/geoscene/manager"
        echo "  Portal 门户:      https://${host_ip}:${PORTAL_PORT}/geoscene/home"
        echo "  DataStore 配置:   https://${host_ip}:${DATASTORE_PORT}/geoscene/datastore"
        echo ""
    fi
    
    echo -e "\033[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    echo -e "\033[32m  提示:\033[0m"
    echo "    • 各组件状态检查:"
    is_installed server    && echo "      Server:   runuser -u $GS_USER -- $GS_BASE/server/tools/checkserverstatus"
    is_installed portal    && echo "      Portal:   runuser -u $GS_USER -- $GS_BASE/portal/tools/checkportalstatus"
    is_installed datastore && echo "      DataStore: runuser -u $GS_USER -- $GS_BASE/datastore/tools/checkdatastorestatus"
    echo ""
    echo "    • 查看完整日志: cat $LOG_FILE"
    echo ""
    echo -e "\033[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""

    {
        echo "======= GeoScene 安装总结 ======="
        echo "安装时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "安装用户: $GS_USER"
        echo "安装目录: $GS_BASE"
        echo "主机 IP:  $host_ip"
        echo "日志:     $LOG_FILE"
        echo "组件:     ${installed_comps[*]:-无}"
        echo "配置状态: $config_status"
        [[ -n "$server_lic" ]] && echo "Server授权文件: $GS_HOME/$server_lic"
        [[ -n "$portal_lic" ]] && echo "Portal授权文件: $GS_HOME/$portal_lic"
        is_installed server    && echo "URL[Server Manager]: https://${host_ip}:${SERVER_PORT}/geoscene/manager"
        is_installed portal    && echo "URL[Portal]:         https://${host_ip}:${PORTAL_PORT}/geoscene/home"
        is_installed datastore && echo "URL[DataStore]:      https://${host_ip}:${DATASTORE_PORT}/geoscene/datastore"
        echo "管理员账户:"
        echo "  Server: $SITE_ADMIN_USER / $SITE_ADMIN_PASS"
        echo "  Portal: $PORTAL_ADMIN_USER / $PORTAL_ADMIN_PASS"
        echo "================================="
    } >> "$LOG_FILE"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")"; touch "$LOG_FILE"

    echo -e "\033[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[34m  🚀 GeoScene Universal Installer v${SCRIPT_VERSION}\033[0m"
    [[ "$DRY_RUN" == true ]] && \
        echo -e "\033[33m  ⚠️  DRY-RUN 模式，不执行任何实际变更\033[0m"
    [[ "$SKIP_CONFIG" == true ]] && \
        echo -e "\033[33m  ⚠️  跳过自动化配置模式\033[0m"
    echo -e "\033[34m  📋 日志: $LOG_FILE\033[0m"
    echo -e "\033[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

    check_prerequisites
    scan_workspace
    setup_system

    for comp in server portal datastore; do
        [[ -n "${FOUND_INSTALLERS[$comp]+_}" ]] && \
            install_component "$comp" "${FOUND_INSTALLERS[$comp]}"
    done

    copy_license_files

    if [[ "$SKIP_CONFIG" == false ]]; then
        log_host_ip
        
        print_task_header "自动化配置阶段"
        
        print_subtask "Server 启动与配置"
        start_server || true
        if check_server_running; then
            authorize_server || true
            create_server_site || true
            
            if check_server_running; then
                print_subtask "等待 Server 服务完全就绪..."
                sleep 60
                ensure_publishing_tools || true
            fi
        else
            print_subtask_warn "Server 未运行，跳过授权和站点创建"
        fi
        
        print_subtask "DataStore 启动与配置"
        start_datastore || true
        if check_datastore_running; then
            if check_server_running; then
                print_subtask "等待 DataStore 完全就绪..."
                sleep 30
                configure_datastore || true
            else
                print_subtask_warn "Server 未运行，跳过 DataStore 配置"
            fi
        else
            print_subtask_warn "DataStore 未运行，跳过配置"
        fi
        
        print_subtask "Portal 启动与配置"
        start_portal || true
        if check_portal_running; then
            print_subtask "等待 Portal 完全就绪..."
            sleep 30
            create_portal || true
            if check_portal_initialized; then
                update_portal_webcontext || true
            else
                print_subtask_warn "Portal 未正确初始化，跳过 WebContextURL 更新"
            fi
        else
            print_subtask_warn "Portal 未运行，跳过门户创建"
        fi
    else
        log_host_ip
        start_server || true
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_dry "预演结束，去掉 --dry-run 后重新运行"
    else
        print_summary
    fi
}

main "$@"