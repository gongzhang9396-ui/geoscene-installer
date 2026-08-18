#!/usr/bin/env bash
#==============================================================================
# GeoScene Enterprise Universal Installer (v7.0)
# 支持: 全自动化安装配置 | 实际IP网络配置 | 主机名/FQDN配置 | 证书管理
# 支持: Tomcat/JDK自动下载安装 | 多平台支持 | 幂等执行 | 架构检查
# 支持: help参数 | 配置文件 | 静默模式 | DRY-RUN模式 | 重试机制
#==============================================================================
set -euo pipefail
shopt -s nullglob extglob

SCRIPT_VERSION="7.0"
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
DATA_DIR=""
LICENSE_DIR=""
SERVER_LICENSE_FILE=""
PORTAL_LICENSE_FILE=""
JDK_TARBALL=""
TOMCAT_TARBALL=""
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
PORTAL_ADMIN_USER_TYPE="creatorUT"
PORTAL_ADMIN_EMAIL="portaladmin@example.com"
PORTAL_ADMIN_FN="Admin"
PORTAL_ADMIN_LN="User"
PORTAL_ADMIN_QI="1"
PORTAL_ADMIN_QA="Beijing"

# 主机名/FQDN配置（关键：避免localhost问题）
HOSTNAME=""
FQDN=""
CONFIGURE_HOSTNAME=true
CONFIGURE_HOSTS=true
DISABLE_IPV6=true

# WebAdaptor配置（v7.0: 变为必选组件）
INSTALL_WEBADAPTOR=true
TOMCAT_VERSION="9.0.89"
TOMCAT_HOME=""
JDK_VERSION="17"
JDK_HOME=""
WEBADAPTOR_PORT="443"
WEBADAPTOR_CONTEXT="geoscene"
SERVER_WEBADAPTOR_CONTEXT="server"

# JDK下载配置
JDK_PROVIDER="adoptium"
JDK_BASE_URL="https://api.adoptium.net"

# Tomcat下载配置
TOMCAT_BASE_URL="https://dlcdn.apache.org/tomcat/tomcat-9"

# 证书配置
CREATE_SELF_SIGNED_CERT=true
CERT_COUNTRY="CN"
CERT_STATE="Beijing"
CERT_CITY="Beijing"
CERT_ORG="GeoScene"
CERT_OU="Product Department"
CERT_EMAIL="admin@geoscene.cn"
CERT_DAYS="3650"
CERT_PASSWORD="geoscene"

# 自动下载配置
AUTO_DOWNLOAD=true

CONFIG_FILE=""
DRY_RUN=false
SKIP_CONFIG=false
SKIP_HOSTNAME=false
REINSTALL=false
HOST_IP=""

#==============================================================================
# 帮助函数定义（必须在参数解析前）
#==============================================================================
show_help() {
    cat << 'EOF'
GeoScene Enterprise Installer v7.0

用法: install-geoscene.sh [选项]

选项:
  -h, --help              显示此帮助信息
  --man                   显示完整手册页
  -n, --dry-run           预演模式，不执行实际变更
  --config=FILE           指定配置文件 (默认: geoscene.conf)
  --skip-config           仅安装软件，跳过站点配置
  --skip-hostname         跳过主机名和hosts配置
  --disable-ipv6          禁用IPv6，确保localhost解析为127.0.0.1
  --gs-user=USER          GeoScene 运行用户 (默认: geoscene)
  --gs-base=DIR           安装基础目录 (默认: /home/geoscene/geoscene)
  --fqdn=DOMAIN           设置完全限定域名(FQDN)
  --hostname=NAME         设置主机名
  --jdk-version=VERSION   JDK版本 (17/11/8, 默认: 17)
  --tomcat-version=VER    Tomcat版本 (默认: 9.0.89)
  --create-cert           创建自签名证书

必需组件 (v7.0):
  - Server安装包 (GeoScene_Server_Linux_*.tar.gz)
  - Portal安装包 (GeoScene_Portal_Linux_*.tar.gz)
  - DataStore安装包 (GeoScene_DataStore_Linux_*.tar.gz)
  - WebAdaptor安装包 (GeoScene_Web_Adaptor_java_Linux_*.tar.gz)

示例:
  # 使用配置文件全自动安装
  bash install-geoscene.sh --config=geoscene.conf

  # 指定FQDN进行安装
  bash install-geoscene.sh --fqdn=portal.geosceneenterprise.cn

  # 预演模式
  bash install-geoscene.sh --dry-run
EOF
}

show_man() {
    cat << 'EOF'
GEOSCENE-INSTALL(1)          GeoScene Enterprise Installer

名称
    install-geoscene.sh - GeoScene Enterprise 全自动化安装脚本 v7.0

描述
    本脚本提供 GeoScene Enterprise (Server, Portal, DataStore, WebAdaptor)
    的全自动安装部署，包括软件安装、授权、站点创建、门户初始化、
    DataStore配置、主机名配置、域名映射、证书管理、WebAdaptor自动安装、
    JDK/Tomcat自动下载安装、多平台支持、幂等执行。

必需组件 (v7.0)
    - Server安装包 (GeoScene_Server_Linux_*.tar.gz)
    - Portal安装包 (GeoScene_Portal_Linux_*.tar.gz)
    - DataStore安装包 (GeoScene_DataStore_Linux_*.tar.gz)
    - WebAdaptor安装包 (GeoScene_Web_Adaptor_java_Linux_*.tar.gz)
    - Server授权文件 (*.prvc 或 *.ecp)
    - Portal授权文件 (*portal*.json 或 *enterprise*.json)

工作流程
    1. 前置校验 (权限、资源、端口、架构)
    2. 系统配置 (用户、防火墙、limits、systemd、hostname、hosts)
    3. 自动下载JDK和Tomcat (Adoptium/Apache官方源)
    4. 创建自签名SSL证书
    5. 安装Server、Portal、DataStore、WebAdaptor
    6. Server授权和站点创建
    7. DataStore配置
    8. Portal门户创建
    9. WebAdaptor配置

版本历史
    v7.0 - 新增: JDK/Tomcat自动下载、幂等执行、多平台支持、架构检查
    v6.0 - 新增: 主机名/FQDN配置、证书管理、WebAdaptor
    v5.1 - 增强稳定性
    v5.0 - 全自动化配置
EOF
}

#==============================================================================
# 解析命令行参数
#==============================================================================
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=true ;;
        --help|-h) show_help; exit 0 ;;
        --man) show_man; exit 0 ;;
        --skip-config) SKIP_CONFIG=true ;;
        --skip-hostname) SKIP_HOSTNAME=true ;;
        --disable-ipv6) DISABLE_IPV6=true ;;
        --reinstall) REINSTALL=true ;;
        --config=*) CONFIG_FILE="${arg#*=}" ;;
        --data-dir=*) DATA_DIR="${arg#*=}" ;;
        --gs-user=*) GS_USER="${arg#*=}" ;;
        --gs-base=*) GS_BASE="${arg#*=}" ;;
        --fqdn=*) FQDN="${arg#*=}" ;;
        --hostname=*) HOSTNAME="${arg#*=}" ;;
        --jdk-version=*) JDK_VERSION="${arg#*=}" ;;
        --tomcat-version=*) TOMCAT_VERSION="${arg#*=}" ;;
        --create-cert) CREATE_SELF_SIGNED_CERT=true ;;
    esac
done

#==============================================================================
# 加载配置文件
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
                GS_USER) GS_USER="$value" ;;
                GS_GROUP) GS_GROUP="$value" ;;
                GS_HOME) GS_HOME="$value" ;;
                GS_BASE) GS_BASE="$value" ;;
                DATA_DIR) DATA_DIR="$value" ;;
                LICENSE_DIR) LICENSE_DIR="$value" ;;
                SERVER_LICENSE_FILE) SERVER_LICENSE_FILE="$value" ;;
                PORTAL_LICENSE_FILE) PORTAL_LICENSE_FILE="$value" ;;
                JDK_TARBALL) JDK_TARBALL="$value" ;;
                TOMCAT_TARBALL) TOMCAT_TARBALL="$value" ;;
                SERVER_PORT) SERVER_PORT="$value" ;;
                PORTAL_PORT) PORTAL_PORT="$value" ;;
                DATASTORE_PORT) DATASTORE_PORT="$value" ;;
                SITE_ADMIN_USER) SITE_ADMIN_USER="$value" ;;
                SITE_ADMIN_PASS) SITE_ADMIN_PASS="$value" ;;
                PORTAL_ADMIN_USER) PORTAL_ADMIN_USER="$value" ;;
                PORTAL_ADMIN_PASS) PORTAL_ADMIN_PASS="$value" ;;
                PORTAL_ADMIN_USER_TYPE) PORTAL_ADMIN_USER_TYPE="$value" ;;
                PORTAL_ADMIN_EMAIL) PORTAL_ADMIN_EMAIL="$value" ;;
                PORTAL_ADMIN_FN) PORTAL_ADMIN_FN="$value" ;;
                PORTAL_ADMIN_LN) PORTAL_ADMIN_LN="$value" ;;
                PORTAL_ADMIN_QI) PORTAL_ADMIN_QI="$value" ;;
                PORTAL_ADMIN_QA) PORTAL_ADMIN_QA="$value" ;;
                MIN_RAM_MB) MIN_RAM_MB="$value" ;;
                MIN_CPU_CORES) MIN_CPU_CORES="$value" ;;
                MIN_DISK_HOME_GB) MIN_DISK_HOME_GB="$value" ;;
                MIN_DISK_INSTALL_GB) MIN_DISK_INSTALL_GB="$value" ;;
                HOSTNAME) HOSTNAME="$value" ;;
                FQDN) FQDN="$value" ;;
                CONFIGURE_HOSTNAME) [[ "$value" == "true" ]] && CONFIGURE_HOSTNAME=true || CONFIGURE_HOSTNAME=false ;;
                CONFIGURE_HOSTS) [[ "$value" == "true" ]] && CONFIGURE_HOSTS=true || CONFIGURE_HOSTS=false ;;
                DISABLE_IPV6) [[ "$value" == "true" ]] && DISABLE_IPV6=true || DISABLE_IPV6=false ;;
                INSTALL_WEBADAPTOR) [[ "$value" == "true" ]] && INSTALL_WEBADAPTOR=true || INSTALL_WEBADAPTOR=false ;;
                TOMCAT_HOME) TOMCAT_HOME="$value" ;;
                JDK_HOME) JDK_HOME="$value" ;;
                JDK_VERSION) JDK_VERSION="$value" ;;
                TOMCAT_VERSION) TOMCAT_VERSION="$value" ;;
                WEBADAPTOR_PORT) WEBADAPTOR_PORT="$value" ;;
                WEBADAPTOR_CONTEXT) WEBADAPTOR_CONTEXT="$value" ;;
                SERVER_WEBADAPTOR_CONTEXT) SERVER_WEBADAPTOR_CONTEXT="$value" ;;
                CREATE_SELF_SIGNED_CERT) [[ "$value" == "true" ]] && CREATE_SELF_SIGNED_CERT=true || CREATE_SELF_SIGNED_CERT=false ;;
                CERT_COUNTRY) CERT_COUNTRY="$value" ;;
                CERT_STATE) CERT_STATE="$value" ;;
                CERT_CITY) CERT_CITY="$value" ;;
                CERT_ORG) CERT_ORG="$value" ;;
                CERT_OU) CERT_OU="$value" ;;
                CERT_EMAIL) CERT_EMAIL="$value" ;;
                CERT_DAYS) CERT_DAYS="$value" ;;
                CERT_PASSWORD) CERT_PASSWORD="$value" ;;
                AUTO_DOWNLOAD) [[ "$value" == "true" ]] && AUTO_DOWNLOAD=true || AUTO_DOWNLOAD=false ;;
            esac
        done < "$conf_path"
        echo "[SUCCESS] 配置文件已加载"
    fi
}

load_config_from_file

# 重新解析命令行参数（覆盖配置文件）
for arg in "$@"; do
    case "$arg" in
        --gs-user=*) GS_USER="${arg#*=}" ;;
        --gs-base=*) GS_BASE="${arg#*=}" ;;
        --data-dir=*) DATA_DIR="${arg#*=}" ;;
        --reinstall) REINSTALL=true ;;
        --fqdn=*) FQDN="${arg#*=}" ;;
        --hostname=*) HOSTNAME="${arg#*=}" ;;
        --tomcat-home=*) TOMCAT_HOME="${arg#*=}" ;;
        --jdk-home=*) JDK_HOME="${arg#*=}" ;;
        --jdk-version=*) JDK_VERSION="${arg#*=}" ;;
        --tomcat-version=*) TOMCAT_VERSION="${arg#*=}" ;;
    esac
done

#==============================================================================
# 常量定义
#==============================================================================
readonly LOG_FILE="/var/log/geoscene_$(date +%Y%m%d_%H%M%S).log"
readonly SILENT_FLAGS="-m silent -l yes"
readonly STATE_FILE="/var/log/.geoscene_install_state"
readonly LIMITS_CONF="/etc/security/limits.d/99-geoscene.conf"
REQUIRED_PORTS=("$SERVER_PORT" "$PORTAL_PORT" "$DATASTORE_PORT" "9876" "9877")
[[ "$INSTALL_WEBADAPTOR" == true ]] && REQUIRED_PORTS+=("$WEBADAPTOR_PORT")

# 设置默认值
[[ -n "$JDK_VERSION" ]] || JDK_VERSION="17"
[[ -n "$TOMCAT_VERSION" ]] || TOMCAT_VERSION="9.0.89"
[[ -n "$JDK_HOME" ]] || JDK_HOME="$GS_BASE/jdk"
[[ -n "$TOMCAT_HOME" ]] || TOMCAT_HOME="$GS_BASE/tomcat"
[[ -n "$DATA_DIR" ]] || DATA_DIR="$SCRIPT_DIR"
[[ -n "$LICENSE_DIR" ]] || LICENSE_DIR="$DATA_DIR/licfile"
WEBADAPTOR_SSL_DIR="$TOMCAT_HOME/ssl"
WEBADAPTOR_CERT_PREFIX="webcert"

existing_path_for_df() {
    local path="$1"
    while [[ ! -e "$path" && "$path" != "/" ]]; do
        path=$(dirname "$path")
    done
    printf '%s\n' "$path"
}

#==============================================================================
# 动态调整路径
#==============================================================================
if [[ "$GS_HOME" == "/home/geoscene" && "$GS_USER" != "geoscene" ]]; then
    GS_HOME="/home/$GS_USER"
fi
if [[ "$GS_BASE" == "/home/geoscene/geoscene" && "$GS_USER" != "geoscene" ]]; then
    GS_BASE="$GS_HOME/geoscene"
fi

#==============================================================================
# 日志和输出函数 - 清晰、规范、简约大方
#==============================================================================

# 基础日志函数 - 带时间戳，同时输出到终端和日志文件
log() {
    local level="$1" color="$2" msg="$3"
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    local plain="[$level] $ts $msg"
    # 终端带颜色输出
    echo -e "\033[${color}m${plain}\033[0m"
    # 日志文件纯文本输出
    echo "$plain" >> "$LOG_FILE" 2>/dev/null || true
}

# 日志级别函数
log_info()    { log "INFO"    "34" "$1"; }  # 蓝色
log_warn()    { log "WARN"    "33" "$1"; }  # 黄色
log_error()   { log "ERROR"   "31" "$1"; }  # 红色
log_success() { log "SUCCESS" "32" "$1"; }  # 绿色
log_dry()     { log "DRY-RUN" "36" "$1"; }  # 青色

#==============================================================================
# 任务输出函数 - 层次清晰，视觉美观
#==============================================================================

# 任务标题 - 蓝色背景，醒目大方
print_task_header() {
    local title="$1"
    echo ""
    echo -e "\033[44;37m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m"
    echo -e "\033[44;37m┃  $title\033[0m"
    echo -e "\033[44;37m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
    echo ""
}

# 子任务 - 青色箭头，表示进行中
print_subtask() {
    local title="$1"
    echo -e "\033[36m  ▶ $title\033[0m"
    log_info "$title"
}

# 子任务成功 - 绿色勾选，简洁明了
print_subtask_success() {
    local title="$1"
    echo -e "\033[32m  ✓ $title\033[0m"
    log_success "$title"
}

# 子任务警告 - 黄色感叹号，醒目但不突兀
print_subtask_warn() {
    local title="$1"
    echo -e "\033[33m  ⚠ $title\033[0m"
    log_warn "$title"
}

# 子任务错误 - 红色叉号，清晰可见
print_subtask_error() {
    local title="$1"
    echo -e "\033[31m  ✗ $title\033[0m"
    log_error "$title"
}

#==============================================================================
# IP和主机名函数
#==============================================================================
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

get_current_hostname() {
    hostname -s 2>/dev/null || hostname 2>/dev/null || echo "localhost"
}

get_current_fqdn() {
    hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost"
}

disable_ipv6() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 禁用IPv6"; return 0; }
    [[ "$DISABLE_IPV6" == true ]] || return 0

    print_subtask "禁用IPv6，固定localhost为IPv4..."
    cat > /etc/sysctl.d/99-geoscene-ipv6.conf << 'EOF'
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF
    sysctl --load=/etc/sysctl.d/99-geoscene-ipv6.conf >/dev/null 2>&1 || true
    log_success "IPv6已禁用 [幂等执行]"
}

#==============================================================================
# 安装包扫描
#==============================================================================
trap 'find "$SCRIPT_DIR" -maxdepth 1 -type d -name "geoscene_inst_*" -exec rm -rf {} + 2>/dev/null || true' EXIT

gs_install_dir() { echo "$GS_BASE/$1"; }
is_installed()   { [[ -f "$(gs_install_dir "$1")/.geoscene_installed" ]]; }

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

license_copy_path() {
    local comp="$1" source="${FOUND_LICENSES[$1]}"
    echo "$GS_HOME/geoscene-${comp}-license.${source##*.}"
}

to_lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

declare -gA FOUND_INSTALLERS=()
declare -gA FOUND_LICENSES=()
declare -ga COMPONENT_QUEUE=()

scan_workspace() {
    FOUND_INSTALLERS=(); FOUND_LICENSES=(); COMPONENT_QUEUE=()

    for f in "$DATA_DIR"/*; do
        [[ -f "$f" ]] || continue
        local base="${f##*/}"
        local lower; lower=$(to_lower "$base")

        if [[ "$base" == *.tar.gz || "$base" == *.tgz ]]; then
            # Windows安装包检查
            if [[ "$lower" == *windows* || "$lower" == *win* || "$lower" == *.exe || "$lower" == *.msi ]]; then
                log_warn "检测到Windows安装包，跳过: $base"
                continue
            fi

            # 架构检查
            local pkg_arch=""
            local sys_arch=$(uname -m)
            [[ "$sys_arch" == "x86_64" ]] && sys_arch="x86_64"
            [[ "$sys_arch" == "aarch64" || "$sys_arch" == "arm64" ]] && sys_arch="arm64"

            if [[ "$lower" == *x64* || "$lower" == *x86_64* || "$lower" == *amd64* ]]; then
                pkg_arch="x86_64"
            elif [[ "$lower" == *arm64* || "$lower" == *aarch64* ]]; then
                pkg_arch="arm64"
            fi

            if [[ -n "$pkg_arch" && "$pkg_arch" != "$sys_arch" ]]; then
                log_warn "架构不匹配: $base ($pkg_arch) vs 系统 ($sys_arch)，跳过"
                continue
            fi

            # 识别组件
            if [[ "$lower" == *server* && ! "$lower" == *innovator* && ! "$lower" == *web* && ! "$lower" == *data* ]]; then
                FOUND_INSTALLERS[server]="$f"; COMPONENT_QUEUE+=(server)
            elif [[ "$lower" == *portal* ]]; then
                FOUND_INSTALLERS[portal]="$f"; COMPONENT_QUEUE+=(portal)
            elif [[ "$lower" == *data* ]]; then
                FOUND_INSTALLERS[datastore]="$f"; COMPONENT_QUEUE+=(datastore)
            elif [[ "$lower" == *web*adaptor* || "$lower" == *webadaptor* ]]; then
                FOUND_INSTALLERS[webadaptor]="$f"; COMPONENT_QUEUE+=(webadaptor)
            fi

        fi
    done

    local server_license="$SERVER_LICENSE_FILE"
    local portal_license="$PORTAL_LICENSE_FILE"
    [[ -n "$server_license" && "$server_license" != /* ]] && server_license="$LICENSE_DIR/$server_license"
    [[ -n "$portal_license" && "$portal_license" != /* ]] && portal_license="$LICENSE_DIR/$portal_license"

    if [[ -n "$server_license" ]]; then
        [[ -f "$server_license" ]] || { log_error "Server授权文件不存在: $server_license"; exit 1; }
        FOUND_LICENSES[server]="$server_license"
    else
        local server_candidates=()
        mapfile -t server_candidates < <(find "$LICENSE_DIR" "$DATA_DIR" -maxdepth 1 -type f \( -iname '*.prvc' -o -iname '*.ecp' \) -print 2>/dev/null | sort -u)
        if [[ ${#server_candidates[@]} -ne 1 ]]; then
            log_error "Server授权文件不唯一，请配置 SERVER_LICENSE_FILE；候选数量: ${#server_candidates[@]}"
            printf '  %s\n' "${server_candidates[@]}"
            exit 1
        fi
        FOUND_LICENSES[server]="${server_candidates[0]}"
    fi

    if [[ -n "$portal_license" ]]; then
        [[ -f "$portal_license" ]] || { log_error "Portal授权文件不存在: $portal_license"; exit 1; }
        FOUND_LICENSES[portal]="$portal_license"
    else
        local portal_candidates=()
        mapfile -t portal_candidates < <(find "$LICENSE_DIR" "$DATA_DIR" -maxdepth 1 -type f -iname '*.json' \( -iname '*portal*' -o -iname '*enterprise*' \) -print 2>/dev/null | sort -u)
        if [[ ${#portal_candidates[@]} -ne 1 ]]; then
            log_error "Portal授权文件不唯一，请配置 PORTAL_LICENSE_FILE；候选数量: ${#portal_candidates[@]}"
            printf '  %s\n' "${portal_candidates[@]}"
            exit 1
        fi
        FOUND_LICENSES[portal]="${portal_candidates[0]}"
    fi

    if [[ ${#COMPONENT_QUEUE[@]} -eq 0 ]]; then
        log_error "未找到任何 GeoScene 安装包 (.tar.gz)"
        exit 1
    fi

    log_info "发现组件: ${COMPONENT_QUEUE[*]}"

    # v7.0: 检查必需组件
    local has_server=false has_portal=false has_datastore=false has_webadaptor=false
    for comp in "${COMPONENT_QUEUE[@]}"; do
        case "$comp" in
            server) has_server=true ;;
            portal) has_portal=true ;;
            datastore) has_datastore=true ;;
            webadaptor) has_webadaptor=true ;;
        esac
    done

    if [[ "$has_server" == false ]]; then
        log_error "缺少必需组件: Server"
        exit 1
    fi
    if [[ "$has_portal" == false ]]; then
        log_error "缺少必需组件: Portal"
        exit 1
    fi
    if [[ "$has_datastore" == false ]]; then
        log_warn "缺少组件: DataStore (v7.0: 推荐安装)"
    fi
    if [[ "$has_webadaptor" == false ]]; then
        log_error "缺少必需组件: WebAdaptor (v7.0: WebAdaptor是必需组件)"
        log_error "请下载: GeoScene_Web_Adaptor_java_Linux_*.tar.gz"
        exit 1
    fi

    for comp in "${COMPONENT_QUEUE[@]}"; do
        log_info "  [$comp] $(basename "${FOUND_INSTALLERS[$comp]}")"
    done
}

#==============================================================================
# 多平台包管理器
#==============================================================================
get_package_manager() {
    if command -v apt-get &>/dev/null; then echo "apt"
    elif command -v yum &>/dev/null; then echo "yum"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v zypper &>/dev/null; then echo "zypper"
    elif command -v pacman &>/dev/null; then echo "pacman"
    else echo "unknown"
    fi
}

install_package() {
    local pkg="$1"
    local pm=$(get_package_manager)
    case "$pm" in
        apt) apt-get update && apt-get install -y "$pkg" ;;
        yum) yum install -y "$pkg" ;;
        dnf) dnf install -y "$pkg" ;;
        zypper) zypper install -y "$pkg" ;;
        pacman) pacman -S --noconfirm "$pkg" ;;
        *) log_warn "未知的包管理器，无法安装 $pkg"; return 1 ;;
    esac
}

ensure_en_us_utf8_locale() {
    if locale -a 2>/dev/null | grep -Eqi '^en_US\.utf-?8$'; then
        log_info "系统语言环境已存在: en_US.UTF-8 [幂等执行]"
        return 0
    fi

    print_subtask "生成 GeoScene 安装器所需的 en_US.UTF-8 语言环境..."
    case "$(get_package_manager)" in
        apt)
            DEBIAN_FRONTEND=noninteractive install_package locales
            locale-gen en_US.UTF-8
            ;;
        yum|dnf)
            install_package glibc-langpack-en
            localedef -c -i en_US -f UTF-8 en_US.UTF-8
            ;;
        *)
            command -v localedef &>/dev/null && localedef -c -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true
            ;;
    esac

    locale -a 2>/dev/null | grep -Eqi '^en_US\.utf-?8$' || {
        log_error "无法生成 en_US.UTF-8 语言环境"
        return 1
    }
    log_success "en_US.UTF-8 语言环境已就绪 [幂等执行]"
}

#==============================================================================
# 配置验证功能
#==============================================================================
validate_config() {
    print_task_header "安装前配置验证"
    local validation_passed=true

    # 1. FQDN格式验证
    if [[ -n "$FQDN" ]]; then
        if [[ ! "$FQDN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
            log_error "FQDN格式无效: $FQDN"
            validation_passed=false
        else
            print_subtask_success "FQDN格式验证通过: $FQDN"
        fi
    fi

    # 2. 密码强度验证
    validate_password() {
        local pass="$1" name="$2"
        local length=${#pass}
        if [[ $length -lt 8 ]]; then
            log_error "$name 密码长度不足8位"
            return 1
        fi
        if [[ ! "$pass" =~ [A-Z] ]]; then
            log_error "$name 密码必须包含大写字母"
            return 1
        fi
        if [[ ! "$pass" =~ [a-z] ]]; then
            log_error "$name 密码必须包含小写字母"
            return 1
        fi
        if [[ ! "$pass" =~ [0-9] ]]; then
            log_error "$name 密码必须包含数字"
            return 1
        fi
        return 0
    }

    validate_password "$SITE_ADMIN_PASS" "Server管理员" || validation_passed=false
    validate_password "$PORTAL_ADMIN_PASS" "Portal管理员" || validation_passed=false

    # 3. 端口范围验证
    validate_port() {
        local port="$1" name="$2"
        if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
            log_error "$name 端口无效: $port (必须是1-65535)"
            return 1
        fi
        return 0
    }

    validate_port "$SERVER_PORT" "Server" || validation_passed=false
    validate_port "$PORTAL_PORT" "Portal" || validation_passed=false
    validate_port "$DATASTORE_PORT" "DataStore" || validation_passed=false

    # 4. 路径验证
    if [[ ! "$GS_HOME" =~ ^/ ]]; then
        log_error "GS_HOME必须是绝对路径: $GS_HOME"
        validation_passed=false
    fi
    if [[ ! "$GS_BASE" =~ ^/ ]]; then
        log_error "GS_BASE必须是绝对路径: $GS_BASE"
        validation_passed=false
    fi

    # 5. 邮箱格式验证
    if [[ ! "$PORTAL_ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Portal管理员邮箱格式无效: $PORTAL_ADMIN_EMAIL"
        validation_passed=false
    else
        print_subtask_success "邮箱格式验证通过"
    fi

    # 6. 依赖命令检查
    local required_commands=("curl" "tar" "hostname" "ip" "awk")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "缺少必需命令: $cmd"
            validation_passed=false
        fi
    done
    print_subtask_success "基础命令依赖检查通过"

    # 7. 磁盘空间预检（更严格的检查）
    local required_gb=$(( MIN_DISK_HOME_GB + MIN_DISK_INSTALL_GB + 10 ))  # 额外10GB缓冲
    if is_installed server && is_installed portal && is_installed datastore && is_installed webadaptor; then
        required_gb=1
    fi
    local disk_check_path; disk_check_path=$(existing_path_for_df "$GS_HOME")
    local avail_kb=$(df -k "$disk_check_path" 2>/dev/null | awk 'NR==2{print $4}')
    local avail_gb=$(( avail_kb / 1048576 ))
    if [[ "$avail_gb" -lt "$required_gb" ]]; then
        log_warn "磁盘空间可能不足: ${avail_gb}GB可用，建议至少${required_gb}GB"
    else
        print_subtask_success "磁盘空间充足: ${avail_gb}GB"
    fi

    # 8. 内存检查
    local ram_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
    if [[ "$ram_mb" -lt 8192 ]]; then
        log_warn "内存低于推荐值: ${ram_mb}MB (推荐≥8192MB)"
    else
        print_subtask_success "内存检查通过: ${ram_mb}MB"
    fi

    if [[ "$validation_passed" == false ]]; then
        log_error "配置验证失败，请修正以上错误后重试"
        exit 1
    fi

    log_success "所有配置验证通过"
}

#==============================================================================
# 备份功能
#==============================================================================
create_backup() {
    [[ "$DRY_RUN" == true ]] && return 0

    local backup_dir="$GS_HOME/.geoscene_backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    print_task_header "创建安装前备份"

    # 备份现有配置
    if [[ -f "$LIMITS_CONF" ]]; then
        cp "$LIMITS_CONF" "$backup_dir/"
        print_subtask "备份 limits.conf"
    fi

    if [[ -f "/etc/systemd/system.conf" ]]; then
        cp "/etc/systemd/system.conf" "$backup_dir/"
        print_subtask "备份 system.conf"
    fi

    if [[ -f "/etc/hosts" ]]; then
        cp "/etc/hosts" "$backup_dir/"
        print_subtask "备份 hosts"
    fi

    if [[ -f "/etc/hostname" ]]; then
        cp "/etc/hostname" "$backup_dir/"
        print_subtask "备份 hostname"
    fi

    # 备份现有GeoScene安装（如果存在）
    for comp in server portal datastore; do
        local comp_home; comp_home=$(gs_component_home "$comp")
        if [[ -d "$comp_home" ]]; then
            local comp_backup="$backup_dir/${comp}_config"
            mkdir -p "$comp_backup"
            # 备份配置文件目录
            if [[ -d "$comp_home/usr/config-store" ]]; then
                cp -r "$comp_home/usr/config-store" "$comp_backup/" 2>/dev/null || true
            fi
            if [[ -d "$comp_home/usr/arcgisportal" ]]; then
                cp -r "$comp_home/usr/arcgisportal" "$comp_backup/" 2>/dev/null || true
            fi
            print_subtask "备份 $comp 配置"
        fi
    done

    # 保存备份信息
    echo "BACKUP_TIME=$(date '+%Y-%m-%d %H:%M:%S')" > "$backup_dir/backup_info.txt"
    echo "BACKUP_DIR=$backup_dir" >> "$backup_dir/backup_info.txt"

    log_success "备份创建完成: $backup_dir"
    echo "$backup_dir" > /tmp/geoscene_last_backup.txt
}

#==============================================================================
# 重装前清理：停止服务并移动旧目录，保留可恢复备份
#==============================================================================
prepare_reinstall() {
    [[ "$DRY_RUN" == true || "$REINSTALL" == false ]] && return 0

    local backup_dir=""
    [[ -f /tmp/geoscene_last_backup.txt ]] && backup_dir=$(< /tmp/geoscene_last_backup.txt)
    [[ -n "$backup_dir" && -d "$backup_dir" ]] || {
        backup_dir="$GS_HOME/.geoscene_backup/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
    }

    print_task_header "重装前清理（可恢复）"

    local units=(geosceneserver geosceneportal geoscenedatastore geoscene-tomcat
                 geoscene-server geoscene-portal geoscene-datastore)
    local unit
    for unit in "${units[@]}"; do
        systemctl stop "$unit.service" 2>/dev/null || true
        systemctl disable "$unit.service" 2>/dev/null || true
        if [[ -f "/etc/systemd/system/$unit.service" ]]; then
            mkdir -p "$backup_dir/systemd"
            mv "/etc/systemd/system/$unit.service" "$backup_dir/systemd/"
        fi
    done
    systemctl daemon-reload 2>/dev/null || true

    # 官方停止脚本作为 systemd 之外的兜底
    for comp in server portal datastore; do
        local stop_script="$GS_BASE/$comp/stop${comp}.sh"
        [[ -x "$stop_script" ]] && runuser -u "$GS_USER" -- "$stop_script" 2>/dev/null || true
    done

    local old_root="$backup_dir/old-install"
    mkdir -p "$old_root"
    local label path
    for label in server portal datastore jdk tomcat; do
        case "$label" in
            server|portal|datastore) path="$GS_BASE/$label" ;;
            jdk) path="$JDK_HOME" ;;
            tomcat) path="$TOMCAT_HOME" ;;
        esac
        [[ -d "$path" ]] || continue
        # 防止配置把多个组件指向同一个目录时重复移动
        [[ -e "$old_root/$label" ]] && continue
        mv "$path" "$old_root/$label"
        print_subtask "已移动旧目录: $path"
    done

    log_success "旧安装已保存在: $old_root"
}

#==============================================================================
# 回滚功能
#==============================================================================
rollback_installation() {
    local backup_dir="$1"
    if [[ -z "$backup_dir" ]] || [[ ! -d "$backup_dir" ]]; then
        log_error "未找到有效的备份目录"
        return 1
    fi

    print_task_header "执行回滚操作"

    # 停止服务
    for comp in server portal datastore; do
        local stop_script="$GS_BASE/$comp/stop${comp}.sh"
        [[ -f "$stop_script" ]] && runuser -u "$GS_USER" -- "$stop_script" 2>/dev/null || true
    done

    # 恢复配置
    if [[ -f "$backup_dir/limits.conf" ]]; then
        cp "$backup_dir/limits.conf" "$LIMITS_CONF"
        print_subtask "恢复 limits.conf"
    fi

    if [[ -f "$backup_dir/system.conf" ]]; then
        cp "$backup_dir/system.conf" "/etc/systemd/system.conf"
        print_subtask "恢复 system.conf"
    fi

    if [[ -f "$backup_dir/hosts" ]]; then
        cp "$backup_dir/hosts" "/etc/hosts"
        print_subtask "恢复 hosts"
    fi

    if [[ -f "$backup_dir/hostname" ]]; then
        cp "$backup_dir/hostname" "/etc/hostname"
        hostname "$(cat /etc/hostname)" 2>/dev/null || true
        print_subtask "恢复 hostname"
    fi

    systemctl daemon-reload 2>/dev/null || true

    log_success "回滚完成"
}

#==============================================================================
# 前置校验
#==============================================================================
check_prerequisites() {
    [[ $EUID -ne 0 ]] && { log_error "需 root 权限执行"; exit 1; }

    # 执行配置验证
    validate_config

    local ram_mb cpu_cores sys_arch
    ram_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
    cpu_cores=$(nproc)
    sys_arch=$(uname -m)

    (( ram_mb < MIN_RAM_MB )) && log_warn "内存 ${ram_mb}MB < ${MIN_RAM_MB}MB"
    (( cpu_cores < MIN_CPU_CORES )) && log_warn "CPU ${cpu_cores}核 < ${MIN_CPU_CORES}核"

    log_info "系统架构: $sys_arch, CPU: ${cpu_cores}核, 内存: ${ram_mb}MB"

    # 磁盘检查
    _check_disk() {
        local path="$1" req_gb="$2"
        local disk_path; disk_path=$(existing_path_for_df "$path")
        local avail_kb; avail_kb=$(df -k "$disk_path" 2>/dev/null | awk 'NR==2{print $4}')
        [[ -z "$avail_kb" ]] && { log_error "无法读取 $path 磁盘空间"; return 1; }
        local avail_gb=$(( avail_kb / 1048576 ))
        (( avail_gb < req_gb )) && { log_error "$path 可用 ${avail_gb}GB < ${req_gb}GB"; return 1; }
        log_info "磁盘 $path: ${avail_gb}GB 可用"
    }
    _check_disk "$GS_HOME" "$MIN_DISK_HOME_GB" || exit 1
    local install_disk_gb="$MIN_DISK_INSTALL_GB"
    if is_installed server && is_installed portal && is_installed datastore && is_installed webadaptor; then
        install_disk_gb=1
        log_info "全部组件已安装，磁盘检查切换为配置模式"
    fi
    _check_disk "$SCRIPT_DIR" "$install_disk_gb" || exit 1

    # 端口检查
    local conflict=false
    for port in "${REQUIRED_PORTS[@]}"; do
        local listeners=""
        listeners=$(ss -ltnpH 2>/dev/null | grep -E ":${port}([[:space:]]|$)" || true)
        [[ -z "$listeners" ]] && continue

        # Idempotent reruns must accept listeners owned by this installation.
        # Reject only a listener whose command line clearly belongs to another
        # service, while still allowing Java/PostgreSQL component processes.
        local owned=false pid cmd
        while read -r _ _ _ _ _ process; do
            pid=$(echo "$process" | grep -oP 'pid=\K[0-9]+' | head -1 || true)
            [[ -z "$pid" ]] && continue
            cmd=$(ps -p "$pid" -o args= 2>/dev/null || true)
            if [[ "$cmd" == *"$GS_BASE"* || "$cmd" == *"$TOMCAT_HOME"* ]]; then
                owned=true
                break
            fi
        done <<< "$listeners"
        if [[ "$owned" == true ]]; then
            log_info "端口 $port 已由 GeoScene 组件占用 [幂等执行]"
        else
            log_error "端口 $port 已被其他进程占用"
            conflict=true
        fi
    done
    [[ "$conflict" == true ]] && { log_error "端口冲突"; exit 1; }

    log_success "前置校验通过"
}

#==============================================================================
# 系统配置（幂等执行）
#==============================================================================
setup_system() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 系统配置"; return 0; }

    print_task_header "系统基础配置"

    # 创建用户和组
    if ! getent group "$GS_GROUP" &>/dev/null; then
        groupadd "$GS_GROUP"
        log_info "创建组: $GS_GROUP"
    else
        log_info "组已存在: $GS_GROUP"
    fi

    if ! id "$GS_USER" &>/dev/null; then
        useradd -m -s /bin/bash -g "$GS_GROUP" -d "$GS_HOME" "$GS_USER"
        log_info "创建用户: $GS_USER"
    else
        log_info "用户已存在: $GS_USER"
    fi

    # create_backup may have created GS_HOME before useradd ran.  Ensure the
    # service account can write its own home before any vendor installer runs.
    mkdir -p "$GS_HOME"
    chown "$GS_USER:$GS_GROUP" "$GS_HOME"

    ensure_en_us_utf8_locale
    sysctl -w vm.swappiness=1 vm.max_map_count=262144 >/dev/null

    # 配置 limits.conf（幂等）
    local limits_content="# GeoScene Enterprise - managed by installer
$GS_USER soft nofile 65536
$GS_USER hard nofile 65536
$GS_USER soft nproc  25059
$GS_USER hard nproc  25059"

    if [[ -f "$LIMITS_CONF" ]]; then
        cp "$LIMITS_CONF" "$LIMITS_CONF.bak.$(date +%Y%m%d%H%M%S)"
    fi
    echo "$limits_content" > "$LIMITS_CONF"
    log_success "limits.conf 已配置 [幂等执行]"

    # 配置 systemd system.conf（幂等）
    local systemd_conf="/etc/systemd/system.conf"
    if [[ -f "$systemd_conf" ]]; then
        cp "$systemd_conf" "$systemd_conf.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        if ! grep -q "^DefaultLimitNOFILE=65536" "$systemd_conf" 2>/dev/null || \
           ! grep -q "^DefaultLimitNPROC=25059" "$systemd_conf" 2>/dev/null; then
            sed -i '/^# GeoScene Enterprise/,/^$/d' "$systemd_conf"
            cat >> "$systemd_conf" << EOF

# GeoScene Enterprise Configuration
DefaultLimitNOFILE=65536
DefaultLimitNPROC=25059
EOF
            systemctl daemon-reload 2>/dev/null || true
            log_success "systemd system.conf 已更新 [幂等执行]"
        else
            log_info "systemd 配置已存在 [幂等执行]"
        fi
    fi

    mkdir -p "$GS_BASE"
    chown "$GS_USER:$GS_GROUP" "$GS_BASE"

    # 防火墙配置
    if command -v firewall-cmd &>/dev/null; then
        for p in "${REQUIRED_PORTS[@]}"; do
            firewall-cmd --permanent --add-port="${p}/tcp" &>/dev/null || true
        done
        firewall-cmd --reload &>/dev/null || true
        log_info "firewall-cmd 已开放端口"
    elif command -v ufw &>/dev/null; then
        for p in "${REQUIRED_PORTS[@]}"; do
            ufw allow "${p}/tcp" &>/dev/null || true
        done
        log_info "ufw 已开放端口"
    fi

    echo "INSTALLED=$(date '+%Y-%m-%d %H:%M:%S')" > "$STATE_FILE"
    log_success "系统基础配置完成 [幂等执行]"
}

#==============================================================================
# 主机名和Hosts配置（幂等执行）
#==============================================================================
configure_hostname_and_hosts() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 主机名和hosts配置"; return 0; }
    [[ "$SKIP_HOSTNAME" == true ]] && { log_info "跳过主机名配置"; return 0; }

    print_task_header "主机名与域名配置 [幂等执行]"

    local current_hostname=$(get_current_hostname)
    local current_fqdn=$(get_current_fqdn)
    local host_ip=$(get_host_ip)

    print_subtask "当前主机名: $current_hostname, FQDN: $current_fqdn, IP: $host_ip"

    # 自动检测或设置FQDN
    if [[ -z "$FQDN" ]]; then
        if [[ "$current_fqdn" != "localhost" && "$current_fqdn" != "localhost.localdomain" && "$current_fqdn" != "$current_hostname" ]]; then
            FQDN="$current_fqdn"
            log_info "自动检测到 FQDN: $FQDN"
        else
            FQDN="geoscene-$(echo "$host_ip" | tr '.' '-').local"
            log_warn "未配置FQDN，使用默认值: $FQDN"
        fi
    fi

    [[ -z "$HOSTNAME" ]] && HOSTNAME=$(echo "$FQDN" | cut -d'.' -f1)

    # 配置主机名
    if [[ "$CONFIGURE_HOSTNAME" == true && "$current_hostname" != "$HOSTNAME" ]]; then
        print_subtask "设置主机名为: $HOSTNAME"
        echo "$HOSTNAME" > /etc/hostname
        hostname "$HOSTNAME" 2>/dev/null || hostnamectl set-hostname "$HOSTNAME" 2>/dev/null || true
        log_success "主机名已设置: $HOSTNAME [幂等执行]"
    fi

    # 配置 hosts
    if [[ "$CONFIGURE_HOSTS" == true ]]; then
        print_subtask "配置 /etc/hosts..."
        local hosts_file="/etc/hosts"
        [[ -f "$hosts_file" ]] && cp "$hosts_file" "$hosts_file.bak.$(date +%Y%m%d%H%M%S)"

        # 移除旧的相同IP条目
        grep -v "^${host_ip}[[:space:]]" "$hosts_file" > "${hosts_file}.tmp" 2>/dev/null || cat "$hosts_file" > "${hosts_file}.tmp"

        # 添加新的hosts条目；禁用IPv6时不要保留::1 localhost映射。
        cat > "${hosts_file}.new" << EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
# GeoScene Enterprise Configuration
${host_ip}   ${FQDN} ${HOSTNAME}
EOF
        if [[ "$DISABLE_IPV6" != true ]]; then
            sed -i '2i::1         localhost localhost.localdomain localhost6 localhost6.localdomain6' "${hosts_file}.new"
        fi
        grep -v "^#" "${hosts_file}.tmp" | grep -v "^127\." | grep -v "^::" | grep -v "^${host_ip}[[:space:]]" >> "${hosts_file}.new" 2>/dev/null || true
        mv "${hosts_file}.new" "$hosts_file"
        rm -f "${hosts_file}.tmp"
        log_success "/etc/hosts 已配置 [幂等执行]"
    fi

    log_success "主机名与域名配置完成 [幂等执行]"
}

#==============================================================================
# JDK下载安装（Adoptium）
#==============================================================================
download_and_install_jdk() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: JDK下载安装"; return 0; }

    # 检查是否已安装
    if [[ -d "$JDK_HOME" ]] && [[ -f "$JDK_HOME/bin/java" ]]; then
        log_info "JDK 已存在，跳过下载 [幂等执行]"
        return 0
    fi

    print_task_header "准备 JDK ${JDK_VERSION}"

    local jdk_tarball="$JDK_TARBALL" downloaded=false
    if [[ -z "$jdk_tarball" ]]; then
        jdk_tarball=$(find "$DATA_DIR" -maxdepth 1 -type f -iname 'jdk*.tar.gz' -print 2>/dev/null | sort | head -n1)
    elif [[ "$jdk_tarball" != /* ]]; then
        jdk_tarball="$DATA_DIR/$jdk_tarball"
    fi

    if [[ -n "$jdk_tarball" && -f "$jdk_tarball" ]]; then
        print_subtask "使用本地 JDK 包: $(basename "$jdk_tarball")"
    elif [[ "$AUTO_DOWNLOAD" == false ]]; then
        log_error "未找到本地 JDK 包，且 AUTO_DOWNLOAD=false"
        return 1
    else
        print_subtask "从 Adoptium 下载 JDK..."
    fi

    local arch=$(uname -m)
    local jvm_arch=""
    case "$arch" in
        x86_64) jvm_arch="x64" ;;
        aarch64|arm64) jvm_arch="aarch64" ;;
        *) log_error "不支持的架构: $arch"; return 1 ;;
    esac

    mkdir -p "$JDK_HOME"
    if [[ ! -f "$jdk_tarball" ]]; then
        local jdk_url="${JDK_BASE_URL}/v3/binary/latest/${JDK_VERSION}/ga/linux/${jvm_arch}/jdk/hotspot/normal/eclipse"
        jdk_tarball="/tmp/jdk-${JDK_VERSION}-${jvm_arch}.tar.gz"
        downloaded=true
        if command -v curl &>/dev/null; then
            curl -fSL --retry 3 "$jdk_url" -o "$jdk_tarball" 2>/dev/null || return 1
        elif command -v wget &>/dev/null; then
            wget --tries=3 "$jdk_url" -O "$jdk_tarball" 2>/dev/null || return 1
        else
            log_error "缺少 curl/wget，无法下载 JDK"
            return 1
        fi
    fi

    print_subtask "解压JDK..."
    rm -rf "$JDK_HOME"/* 2>/dev/null || true
    if ! tar -xzf "$jdk_tarball" -C "$JDK_HOME" --strip-components=1; then
        log_error "JDK解压失败"
        [[ "$downloaded" == true ]] && rm -f "$jdk_tarball"
        return 1
    fi
    [[ "$downloaded" == true ]] && rm -f "$jdk_tarball"

    chown -R "$GS_USER:$GS_GROUP" "$JDK_HOME"

    # 配置环境变量
    cat > /etc/profile.d/geoscene-jdk.sh << EOF
export JAVA_HOME=$JDK_HOME
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
    export JAVA_HOME="$JDK_HOME"
    export PATH="$JDK_HOME/bin:$PATH"

    local java_version=$("$JDK_HOME/bin/java" -version 2>&1 | head -1)
    log_success "JDK安装完成: $java_version [幂等执行]"
}

#==============================================================================
# Tomcat下载安装
#==============================================================================
download_and_install_tomcat() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: Tomcat下载安装"; return 0; }

    # 检查是否已安装
    if [[ -d "$TOMCAT_HOME" ]] && [[ -f "$TOMCAT_HOME/bin/catalina.sh" ]]; then
        log_info "Tomcat 已存在，跳过下载 [幂等执行]"
        return 0
    fi

    print_task_header "准备 Apache Tomcat ${TOMCAT_VERSION}"

    local tomcat_tarball="$TOMCAT_TARBALL" downloaded=false
    if [[ -z "$tomcat_tarball" ]]; then
        tomcat_tarball=$(find "$DATA_DIR" -maxdepth 1 -type f \( -iname 'tomcat*.tar.gz' -o -iname 'apache-tomcat*.tar.gz' \) -print 2>/dev/null | sort | head -n1)
    elif [[ "$tomcat_tarball" != /* ]]; then
        tomcat_tarball="$DATA_DIR/$tomcat_tarball"
    fi

    if [[ -n "$tomcat_tarball" && -f "$tomcat_tarball" ]]; then
        print_subtask "使用本地 Tomcat 包: $(basename "$tomcat_tarball")"
    elif [[ "$AUTO_DOWNLOAD" == false ]]; then
        log_error "未找到本地 Tomcat 包，且 AUTO_DOWNLOAD=false"
        return 1
    else
        print_subtask "从 Apache 下载 Tomcat..."
    fi

    mkdir -p "$TOMCAT_HOME"
    if [[ ! -f "$tomcat_tarball" ]]; then
        local tomcat_url="${TOMCAT_BASE_URL}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
        tomcat_tarball="/tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
        downloaded=true
        if command -v curl &>/dev/null; then
            curl -fSL --retry 3 "$tomcat_url" -o "$tomcat_tarball" 2>/dev/null || return 1
        elif command -v wget &>/dev/null; then
            wget --tries=3 "$tomcat_url" -O "$tomcat_tarball" 2>/dev/null || return 1
        else
            log_error "缺少 curl/wget，无法下载 Tomcat"
            return 1
        fi
    fi

    print_subtask "解压Tomcat..."
    if ! tar -xzf "$tomcat_tarball" -C "$TOMCAT_HOME" --strip-components=1; then
        log_error "Tomcat解压失败"
        [[ "$downloaded" == true ]] && rm -f "$tomcat_tarball"
        return 1
    fi
    [[ "$downloaded" == true ]] && rm -f "$tomcat_tarball"

    # Tomcat安全加固
    print_subtask "应用Tomcat安全配置..."
    rm -rf "$TOMCAT_HOME/webapps/"* 2>/dev/null || true

    local server_xml="$TOMCAT_HOME/conf/server.xml"
    if [[ -f "$server_xml" ]]; then
        cp "$server_xml" "${server_xml}.bak.$(date +%Y%m%d%H%M%S)"
        sanitize_tomcat_connectors "$server_xml" || {
            log_error "Tomcat server.xml 连接器清理失败"
            return 1
        }
        log_success "Tomcat安全配置已应用 [幂等执行]"
    fi

    chown -R "$GS_USER:$GS_GROUP" "$TOMCAT_HOME"
    log_success "Tomcat安装完成 [幂等执行]"
}

sanitize_tomcat_connectors() {
    local server_xml="$1"
    [[ -f "$server_xml" ]] || return 0

    local tmp_xml="${server_xml}.tmp.$$"
    if ! awk '
        BEGIN { skip = 0; in_comment = 0 }
        {
            line = $0
            if (skip) {
                if (line ~ /\/>[[:space:]]*$/ || line ~ /<\/Connector>/) skip = 0
                next
            }
            if (in_comment) {
                print
                if (index(line, "-->") > 0) in_comment = 0
                next
            }
            if (index(line, "<!--") > 0) {
                print
                if (index(line, "-->") == 0) in_comment = 1
                next
            }
            if (line ~ /^[[:space:]]*<Connector[[:space:]]+port="(8080|8009)"/) {
                if (line !~ /\/>[[:space:]]*$/ && line !~ /<\/Connector>/) skip = 1
                next
            }
            print
        }
    ' "$server_xml" > "$tmp_xml"; then
        rm -f "$tmp_xml"
        return 1
    fi
    mv "$tmp_xml" "$server_xml"
    sed -i -E 's/[[:space:]]disabled="true"//g' "$server_xml"
}

#==============================================================================
# 证书创建
#==============================================================================
create_self_signed_certificate() {
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 创建证书"; return 0; }
    [[ "$CREATE_SELF_SIGNED_CERT" == false ]] && { return 0; }

    # 检查是否已存在
    local pfx_file="$WEBADAPTOR_SSL_DIR/${WEBADAPTOR_CERT_PREFIX}.pfx"
    if [[ -f "$pfx_file" ]]; then
        log_info "证书已存在，跳过创建 [幂等执行]"
        return 0
    fi

    print_task_header "创建自签名SSL证书 [幂等执行]"

    if ! command -v openssl &>/dev/null; then
        install_package openssl || { log_error "无法安装openssl"; return 1; }
    fi

    local host_ip=$(get_host_ip)
    local fqdn_to_use="${FQDN:-$host_ip}"

    mkdir -p "$WEBADAPTOR_SSL_DIR"
    chown "$GS_USER:$GS_GROUP" "$WEBADAPTOR_SSL_DIR"

    local key_file="$WEBADAPTOR_SSL_DIR/${WEBADAPTOR_CERT_PREFIX}.key"
    local csr_file="$WEBADAPTOR_SSL_DIR/${WEBADAPTOR_CERT_PREFIX}.csr"
    local crt_file="$WEBADAPTOR_SSL_DIR/${WEBADAPTOR_CERT_PREFIX}.crt"

    openssl genrsa -out "$key_file" 2048 2>/dev/null
    openssl req -new -key "$key_file" -out "$csr_file" \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=${fqdn_to_use}/emailAddress=${CERT_EMAIL}" 2>/dev/null

    echo "subjectAltName=DNS.1:${fqdn_to_use}" > "$WEBADAPTOR_SSL_DIR/cert_extensions"
    openssl x509 -req -sha256 -in "$csr_file" -signkey "$key_file" \
        -extfile "$WEBADAPTOR_SSL_DIR/cert_extensions" -out "$crt_file" -days "$CERT_DAYS" 2>/dev/null

    openssl pkcs12 -inkey "$key_file" -in "$crt_file" -export \
        -out "$pfx_file" -password pass:"$CERT_PASSWORD" 2>/dev/null

    chown "$GS_USER:$GS_GROUP" "$pfx_file"
    chmod 600 "$pfx_file"
    rm -f "$csr_file" "$WEBADAPTOR_SSL_DIR/cert_extensions"

    log_success "自签名证书创建完成 [幂等执行]"
}

#==============================================================================
# 组件安装（幂等）
#==============================================================================
install_component() {
    local comp="$1" tarball="$2"

    if is_installed "$comp"; then
        log_info "$comp 已安装，跳过 [幂等执行]"
        return 0
    fi

    print_task_header "安装 $comp"
    [[ "$DRY_RUN" == true ]] && { log_dry "跳过: 安装 $comp"; return 0; }

    local base_name=$(basename "$tarball")
    local lower=$(to_lower "$base_name")

    # Windows检查
    if [[ "$lower" == *windows* || "$lower" == *win* || "$lower" == *.exe ]]; then
        log_error "检测到Windows安装包: $base_name"
        return 1
    fi

    # 架构检查
    local sys_arch=$(uname -m)
    [[ "$sys_arch" == "aarch64" ]] && sys_arch="arm64"
    local pkg_arch=""
    [[ "$lower" == *x64* || "$lower" == *x86_64* ]] && pkg_arch="x86_64"
    [[ "$lower" == *arm64* || "$lower" == *aarch64* ]] && pkg_arch="arm64"

    if [[ -n "$pkg_arch" && "$pkg_arch" != "$sys_arch" ]]; then
        log_error "架构不匹配: $base_name ($pkg_arch) vs 系统 ($sys_arch)"
        return 1
    fi

    local extract_dir="$SCRIPT_DIR/geoscene_inst_${comp}"
    rm -rf "$extract_dir"; mkdir -p "$extract_dir"

    print_subtask "解压安装包..."
    if ! tar -xzf "$tarball" -C "$extract_dir"; then
        log_error "解压失败: $base_name"
        rm -rf "$extract_dir"
        return 1
    fi

    local installer=$(find "$extract_dir" -maxdepth 3 -type f \( -iname "Setup" -o -iname "setup.sh" \) -executable 2>/dev/null | head -n1)
    [[ -z "$installer" ]] && { log_error "未找到安装入口"; rm -rf "$extract_dir"; return 1; }

    print_subtask "执行静默安装..."
    local install_dir="$(gs_install_dir "$comp")"
    mkdir -p "$install_dir"
    chown "$GS_USER:$GS_GROUP" "$install_dir"
    chown -R "$GS_USER:$GS_GROUP" "$extract_dir"
    local setup_args=(-m silent -l yes -d "$install_dir")
    local staged_license=""
    [[ "$comp" == webadaptor ]] && setup_args=(-l yes -d "$install_dir")
    if [[ "$comp" == server && -n "${FOUND_LICENSES[server]+_}" ]]; then
        staged_license="$extract_dir/server-license.${FOUND_LICENSES[server]##*.}"
        cp "${FOUND_LICENSES[server]}" "$staged_license"
        chown "$GS_USER:$GS_GROUP" "$staged_license"
        chmod 600 "$staged_license"
        setup_args+=(-a "$staged_license")
    fi
    if ! (cd "$(dirname "$installer")" && runuser -u "$GS_USER" -- env HOME="$GS_HOME" JAVA_HOME="$JDK_HOME" PATH="$JDK_HOME/bin:$PATH" "$installer" "${setup_args[@]}"); then
        log_error "$comp 安装失败"
        rm -rf "$extract_dir"
        return 1
    fi

    [[ -n "$staged_license" ]] && rm -f "$staged_license"
    rm -rf "$extract_dir"
    [[ -d "$install_dir" ]] || { log_error "$comp 安装目录未生成: $install_dir"; return 1; }
    chown -R "$GS_USER:$GS_GROUP" "$install_dir"
    touch "$(gs_install_dir "$comp")/.geoscene_installed"
    log_success "$comp 安装完成 [幂等执行]"
}

#==============================================================================
# 授权文件复制（幂等）
#==============================================================================
copy_license_files() {
    local copied=0

    for comp in server portal; do
        [[ -z "${FOUND_LICENSES[$comp]+_}" ]] && continue
        [[ "$DRY_RUN" == true ]] && continue

        local lic_file="${FOUND_LICENSES[$comp]}"
        local lic_dest; lic_dest=$(license_copy_path "$comp")
        local lic_name=$(basename "$lic_dest")

        # 幂等检查
        if [[ -f "$lic_dest" ]] && diff -q "$lic_file" "$lic_dest" &>/dev/null; then
            log_info "授权文件已存在: $lic_name [幂等执行]"
            continue
        fi

        cp "$lic_file" "$lic_dest"
        chown "$GS_USER:$GS_GROUP" "$lic_dest"
        chmod 600 "$lic_dest"
        print_subtask "复制授权: $lic_name [幂等执行]"
        (( copied++ )) || true
    done

    if [[ $copied -gt 0 ]]; then
        log_success "授权文件复制完成 ($copied 个) [幂等执行]"
    else
        log_info "授权文件无需复制 [幂等执行]"
    fi
    return 0
}

#==============================================================================
# Server 操作
#==============================================================================
start_server() {
    [[ "$DRY_RUN" == true ]] && return 0
    local server_home; server_home=$(gs_component_home server)
    local start_script="$server_home/startserver.sh"
    [[ ! -f "$start_script" ]] && return 1

    if ss -ltnH 2>/dev/null | grep -qE ":${SERVER_PORT}[[:space:]]"; then
        log_info "Server 已在运行 [幂等执行]"
        return 0
    fi

    print_subtask "启动 GeoScene Server..."
    runuser -u "$GS_USER" -- env JAVA_HOME="$JDK_HOME" PATH="$JDK_HOME/bin:$PATH" "$start_script" || true

    local max_wait=120 elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        if curl -sk "https://$(get_host_ip):${SERVER_PORT}/geoscene/rest/info" &>/dev/null; then
            log_success "Server 已就绪 [幂等执行]"
            return 0
        fi
        sleep 5; elapsed=$((elapsed + 5))
    done
    log_warn "Server 启动超时"
    return 1
}

check_server_initialized() {
    local host_ip=$(get_host_ip)
    local token=$(curl -sk -X POST "https://${host_ip}:${SERVER_PORT}/geoscene/admin/generateToken" \
        -d "username=$SITE_ADMIN_USER" -d "password=$SITE_ADMIN_PASS" \
        -d "client=requestip" -d "f=json" 2>/dev/null | grep -oP '"token":"[^"]+' | cut -d'"' -f4)
    [[ -n "$token" ]]
}

authorize_server() {
    [[ "$DRY_RUN" == true ]] && return 0
    [[ "$SKIP_CONFIG" == true ]] && return 0

    if check_server_initialized; then
        log_info "Server 已授权 [幂等执行]"
        return 0
    fi

    [[ -z "${FOUND_LICENSES[server]+_}" ]] && { log_warn "缺少Server授权文件"; return 1; }

    print_task_header "Server 授权 [幂等执行]"
    local server_home; server_home=$(gs_component_home server)
    local auth_tool="$server_home/tools/authorizeSoftware"
    [[ ! -f "$auth_tool" ]] && { log_error "未找到授权工具"; return 1; }

    local lic_dest; lic_dest=$(license_copy_path server)
    if runuser -u "$GS_USER" -- "$auth_tool" -f "$lic_dest"; then
        log_success "Server 授权成功 [幂等执行]"
        sleep 10
        return 0
    else
        log_error "Server 授权失败"
        return 1
    fi
}

create_server_site() {
    [[ "$DRY_RUN" == true ]] && return 0
    [[ "$SKIP_CONFIG" == true ]] && return 0

    if check_server_initialized; then
        log_info "Server 站点已存在 [幂等执行]"
        return 0
    fi

    print_task_header "创建 Server 站点 [幂等执行]"
    local server_home; server_home=$(gs_component_home server)
    local site_tool="$server_home/tools/createsite/createsite.sh"
    [[ ! -f "$site_tool" ]] && { log_error "未找到站点创建工具"; return 1; }

    local directories="$server_home/usr/directories"
    local config_store="$server_home/usr/config-store"
    mkdir -p "$directories" "$config_store"
    chown -R "$GS_USER:$GS_GROUP" "$directories" "$config_store"

    if runuser -u "$GS_USER" -- "$site_tool" -u "$SITE_ADMIN_USER" -p "$SITE_ADMIN_PASS" \
        -d "$directories" -c "$config_store"; then
        log_success "Server 站点创建成功 [幂等执行]"
        sleep 30
        return 0
    else
        log_error "Server 站点创建失败"
        return 1
    fi
}

#==============================================================================
# DataStore 操作
#==============================================================================
start_datastore() {
    [[ "$DRY_RUN" == true ]] && return 0
    local datastore_home; datastore_home=$(gs_component_home datastore)
    local start_script="$datastore_home/startdatastore.sh"
    [[ ! -f "$start_script" ]] && return 1

    if ss -ltnH 2>/dev/null | grep -qE ":${DATASTORE_PORT}[[:space:]]"; then
        log_info "DataStore 已在运行 [幂等执行]"
        return 0
    fi

    print_subtask "启动 GeoScene DataStore..."
    runuser -u "$GS_USER" -- env JAVA_HOME="$JDK_HOME" PATH="$JDK_HOME/bin:$PATH" "$start_script" || true

    local max_wait=120 elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        if curl -sk "https://$(get_host_ip):${DATASTORE_PORT}/geoscene/datastore" &>/dev/null; then
            log_success "DataStore 已就绪 [幂等执行]"
            return 0
        fi
        sleep 5; elapsed=$((elapsed + 5))
    done
    log_warn "DataStore 启动超时"
    return 1
}

configure_datastore() {
    [[ "$DRY_RUN" == true ]] && return 0
    [[ "$SKIP_CONFIG" == true ]] && return 0

    print_task_header "配置 DataStore [幂等执行]"
    local datastore_home; datastore_home=$(gs_component_home datastore)
    local ds_tool="$datastore_home/tools/configuredatastore.sh"
    [[ ! -f "$ds_tool" ]] && { log_error "未找到DataStore配置工具"; return 1; }

    local host_ip=$(get_host_ip)
    local public_host="${FQDN:-$host_ip}"
    local ds_data="$datastore_home/usr/datastore"
    mkdir -p "$ds_data"
    chown -R "$GS_USER:$GS_GROUP" "$ds_data"

    if [[ -f "$ds_data/etc/relational-config.json" ]]; then
        log_info "DataStore relational 存储已配置 [幂等执行]"
        return 0
    fi

    if runuser -u "$GS_USER" -- "$ds_tool" \
        "https://${public_host}:${SERVER_PORT}" \
        "$SITE_ADMIN_USER" "$SITE_ADMIN_PASS" "$ds_data" \
        --stores relational; then
        log_success "DataStore 配置成功 [幂等执行]"
        return 0
    else
        log_error "DataStore 配置失败"
        return 1
    fi
}

#==============================================================================
# Portal 操作
#==============================================================================
start_portal() {
    [[ "$DRY_RUN" == true ]] && return 0
    local portal_home; portal_home=$(gs_component_home portal)
    local start_script="$portal_home/startportal.sh"
    [[ ! -f "$start_script" ]] && return 1

    if ss -ltnH 2>/dev/null | grep -qE ":${PORTAL_PORT}[[:space:]]"; then
        log_info "Portal 已在运行 [幂等执行]"
        return 0
    fi

    print_subtask "启动 GeoScene Portal..."
    runuser -u "$GS_USER" -- env JAVA_HOME="$JDK_HOME" PATH="$JDK_HOME/bin:$PATH" "$start_script" || true

    local max_wait=180 elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        if curl -sk "https://$(get_host_ip):${PORTAL_PORT}/geoscene/rest/info" &>/dev/null; then
            log_success "Portal 已就绪 [幂等执行]"
            return 0
        fi
        sleep 10; elapsed=$((elapsed + 10))
    done
    log_warn "Portal 启动超时"
    return 1
}

check_portal_initialized() {
    # The uninitialized Portal endpoint returns a default JSON document that
    # contains a placeholder id (0123456789ABCDEF).  Use the config-store
    # file as the authoritative initialization marker instead of matching any
    # arbitrary nested "id" field in that document.
    local portal_home; portal_home=$(gs_component_home portal)
    [[ -f "$portal_home/framework/etc/config-store-connection.json" ]] || return 1
    local host_ip=$(get_host_ip)
    local response=$(curl -sk "https://${host_ip}:${PORTAL_PORT}/geoscene/sharing/rest/portals/self?f=json" 2>/dev/null)
    echo "$response" | grep -q '"portalName"' && ! echo "$response" | grep -qi '"error"'
}

check_portal_admin_token() {
    local host_ip=$(get_host_ip)
    curl -sk -X POST "https://${host_ip}:${PORTAL_PORT}/geoscene/sharing/rest/generateToken" \
        -d "username=$PORTAL_ADMIN_USER" -d "password=$PORTAL_ADMIN_PASS" \
        -d "client=requestip" -d "f=json" 2>/dev/null | grep -q '"token"'
}

create_portal() {
    [[ "$DRY_RUN" == true ]] && return 0
    [[ "$SKIP_CONFIG" == true ]] && return 0

    if check_portal_initialized; then
        log_info "Portal 已初始化 [幂等执行]"
        return 0
    fi

    [[ -z "${FOUND_LICENSES[portal]+_}" ]] && { log_warn "缺少Portal授权文件"; return 1; }

    print_task_header "创建 Portal 门户 [幂等执行]"
    local portal_home; portal_home=$(gs_component_home portal)
    local portal_tool="$portal_home/tools/createportal/createportal.sh"
    [[ ! -f "$portal_tool" ]] && { log_error "未找到Portal创建工具"; return 1; }

    local portal_content="$portal_home/usr/portal-content"
    mkdir -p "$portal_content"
    chown -R "$GS_USER:$GS_GROUP" "$portal_content"

    local lic_dest; lic_dest=$(license_copy_path portal)

    if runuser -u "$GS_USER" -- "$portal_tool" \
        -fn "$PORTAL_ADMIN_FN" -ln "$PORTAL_ADMIN_LN" \
        -u "$PORTAL_ADMIN_USER" -p "$PORTAL_ADMIN_PASS" \
        -ut "$PORTAL_ADMIN_USER_TYPE" \
        -e "$PORTAL_ADMIN_EMAIL" -qi "$PORTAL_ADMIN_QI" -qa "$PORTAL_ADMIN_QA" \
        -d "$portal_content" -lf "$lic_dest"; then
        log_success "Portal 门户创建成功 [幂等执行]"
        sleep 30
        return 0
    else
        log_error "Portal 门户创建失败"
        return 1
    fi
}

update_portal_webcontext() {
    [[ "$DRY_RUN" == true ]] && return 0
    [[ "$SKIP_CONFIG" == true ]] && return 0

    print_task_header "更新 Portal WebContextURL [幂等执行]"
    local host_ip=$(get_host_ip)

    local portal_token=""
    for _ in {1..12}; do
        portal_token=$(curl -sk -X POST "https://${host_ip}:${PORTAL_PORT}/geoscene/sharing/rest/generateToken" \
            -d "username=$PORTAL_ADMIN_USER" -d "password=$PORTAL_ADMIN_PASS" \
            -d "client=requestip" -d "f=json" 2>/dev/null | grep -oP '"token":"[^"]+' | cut -d'"' -f4)
        [[ -n "$portal_token" ]] && break
        sleep 5
    done
    [[ -z "$portal_token" ]] && { log_warn "无法获取Portal Token"; return 1; }

    local public_host="${FQDN:-$host_ip}"
    local web_context_url="https://${public_host}:${WEBADAPTOR_PORT}/${WEBADAPTOR_CONTEXT}"
    [[ "$WEBADAPTOR_PORT" == "443" ]] && web_context_url="https://${public_host}/${WEBADAPTOR_CONTEXT}"

    if curl -sk -X POST "https://${host_ip}:${PORTAL_PORT}/geoscene/portaladmin/system/updateWebContextURL" \
        -d "webContextURL=$web_context_url" -d "token=$portal_token" -d "f=json" &>/dev/null; then
        log_success "WebContextURL 已更新 [幂等执行]"
        local portal_home; portal_home=$(gs_component_home portal)
        runuser -u "$GS_USER" -- "$portal_home/stopportal.sh" 2>/dev/null || true
        sleep 10
        runuser -u "$GS_USER" -- "$portal_home/startportal.sh" || true
        local elapsed=0
        while [[ $elapsed -lt 180 ]]; do
            if curl -sk "https://${host_ip}:${PORTAL_PORT}/geoscene/rest/info" &>/dev/null; then
                return 0
            fi
            sleep 5
            elapsed=$((elapsed + 5))
        done
        log_warn "Portal 重启后未就绪"
        return 1
    else
        log_warn "WebContextURL 更新失败"
        return 1
    fi
}

#==============================================================================
# WebAdaptor 配置（必需）
#==============================================================================
configure_webadaptor() {
    [[ "$DRY_RUN" == true ]] && return 0
    [[ "$INSTALL_WEBADAPTOR" == false ]] && { log_info "跳过WebAdaptor配置"; return 0; }
    local host_ip=$(get_host_ip)

    print_task_header "配置 GeoScene WebAdaptor [幂等执行]"

    if [[ ! -d "$TOMCAT_HOME" ]]; then
        log_error "Tomcat目录不存在: $TOMCAT_HOME"
        return 1
    fi

    local webadaptor_dir; webadaptor_dir=$(gs_component_home webadaptor)
    [[ ! -d "$webadaptor_dir" ]] && webadaptor_dir="$GS_BASE"

    local war_file=$(find "$webadaptor_dir" -name "geoscene.war" 2>/dev/null | head -1)
    [[ -z "$war_file" ]] && { log_error "未找到 geoscene.war"; return 1; }

    # 部署两个 WebAdaptor context：Portal 使用 /geoscene，Server 使用 /server。
    # 同一个 WebAdaptor WAR 可以通过不同文件名暴露为两个 Tomcat context，
    # 但两者仍必须分别执行 configurewebadaptor.sh 注册。
    local copied_war=false
    if [[ ! -f "$TOMCAT_HOME/webapps/geoscene.war" ]]; then
        print_subtask "部署 Portal WebAdaptor WAR..."
        cp "$war_file" "$TOMCAT_HOME/webapps/geoscene.war"
        copied_war=true
    fi
    if [[ ! -f "$TOMCAT_HOME/webapps/server.war" ]]; then
        print_subtask "部署 Server WebAdaptor WAR..."
        cp "$war_file" "$TOMCAT_HOME/webapps/server.war"
        copied_war=true
    fi
    if [[ "$copied_war" == true ]]; then
        chown "$GS_USER:$GS_GROUP" "$TOMCAT_HOME/webapps/geoscene.war" "$TOMCAT_HOME/webapps/server.war"
        log_success "Portal/Server WebAdaptor WAR 部署完成 [幂等执行]"
    else
        log_info "Portal/Server WebAdaptor WAR 已部署 [幂等执行]"
    fi

    # Make the bare hostname useful; the WebAdaptor itself lives at /geoscene.
    local root_app="$TOMCAT_HOME/webapps/ROOT"
    if [[ ! -f "$root_app/index.jsp" ]]; then
        mkdir -p "$root_app"
        printf '%s\n' '<%@ page contentType="text/html;charset=UTF-8" %><% response.sendRedirect("/geoscene"); %>' > "$root_app/index.jsp"
        chown -R "$GS_USER:$GS_GROUP" "$root_app"
    fi

    # 配置server.xml HTTPS
    local pfx_file="$WEBADAPTOR_SSL_DIR/${WEBADAPTOR_CERT_PREFIX}.pfx"
    if [[ -f "$pfx_file" ]]; then
        cp "$pfx_file" "$TOMCAT_HOME/bin/"
        chown "$GS_USER:$GS_GROUP" "$TOMCAT_HOME/bin/"*.pfx 2>/dev/null || true
    fi

    local server_xml="$TOMCAT_HOME/conf/server.xml"
    if [[ -f "$server_xml" && -f "$pfx_file" ]]; then
        # Recover a previous valid Tomcat configuration if an older installer
        # run truncated server.xml while removing commented Connector examples.
        if ! grep -q '<Engine[[:space:]]' "$server_xml" || ! grep -q '</Engine>' "$server_xml" || ! grep -q '</Service>' "$server_xml"; then
            local backup_xml
            for backup_xml in "$server_xml".bak.*; do
                [[ -f "$backup_xml" ]] || continue
                if grep -q '<Engine[[:space:]]' "$backup_xml" && grep -q '</Engine>' "$backup_xml" && grep -q '</Service>' "$backup_xml"; then
                    cp "$backup_xml" "$server_xml"
                    log_warn "检测到损坏的 server.xml，已从备份恢复: $(basename "$backup_xml")"
                    break
                fi
            done
        fi
        if ! grep -q '<Engine[[:space:]]' "$server_xml" || ! grep -q '</Engine>' "$server_xml" || ! grep -q '</Service>' "$server_xml"; then
            log_error "Tomcat server.xml 结构无效，无法启动 WebAdaptor"
            return 1
        fi
        sanitize_tomcat_connectors "$server_xml" || {
            log_error "Tomcat server.xml 连接器清理失败"
            return 1
        }
        # Disable Tomcat's TCP shutdown socket.  It is unnecessary under
        # systemd and causes repeated/idempotent starts to fail when a stale
        # process still owns port 8005.
        sed -i -E 's#<Server port="[^"]*" shutdown="SHUTDOWN">#<Server port="-1" shutdown="SHUTDOWN">#' "$server_xml"
        if grep -q "GeoScene WebAdaptor HTTPS" "$server_xml"; then
            sed -i -E "s#certificateKeystoreFile=\"[^\"]*\"#certificateKeystoreFile=\"$pfx_file\"#g; s#certificateKeystorePassword=\"[^\"]*\"#certificateKeystorePassword=\"$CERT_PASSWORD\"#g" "$server_xml"
        else
            sed -i "/<\\/Service>/i\\    <!-- GeoScene WebAdaptor HTTPS -->\n    <Connector port=\"$WEBADAPTOR_PORT\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\" SSLEnabled=\"true\" maxThreads=\"150\">\n      <SSLHostConfig>\n        <Certificate certificateKeystoreFile=\"$pfx_file\" certificateKeystoreType=\"PKCS12\" certificateKeystorePassword=\"$CERT_PASSWORD\" />\n      </SSLHostConfig>\n    </Connector>" "$server_xml"
        fi
    fi

    chown -R "$GS_USER:$GS_GROUP" "$TOMCAT_HOME"
    if [[ -f /etc/systemd/system/geoscene-tomcat.service ]]; then
        systemctl daemon-reload
        systemctl restart geoscene-tomcat.service >/dev/null 2>&1 || true
    elif [[ -x "$TOMCAT_HOME/bin/startup.sh" ]] && ! ss -ltnH 2>/dev/null | grep -qE ":${WEBADAPTOR_PORT}[[:space:]]"; then
        runuser -u "$GS_USER" -- env HOME="$GS_HOME" JAVA_HOME="$JDK_HOME" CATALINA_HOME="$TOMCAT_HOME" "$TOMCAT_HOME/bin/startup.sh" >/dev/null 2>&1 || true
    fi
    local elapsed=0
    while [[ $elapsed -lt 60 ]]; do
        if ss -ltnH 2>/dev/null | grep -qE ":${WEBADAPTOR_PORT}[[:space:]]"; then
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    ss -ltnH 2>/dev/null | grep -qE ":${WEBADAPTOR_PORT}[[:space:]]" || { log_error "WebAdaptor端口未监听: $WEBADAPTOR_PORT"; return 1; }

    local wa_tool
    wa_tool=$(find "$webadaptor_dir" -type f -name configurewebadaptor.sh -executable 2>/dev/null | head -1)
    [[ -n "$wa_tool" ]] || { log_error "未找到 configurewebadaptor.sh，无法注册 Portal/Server WebAdaptor"; return 1; }

    local public_host="${FQDN:-$(hostname -f 2>/dev/null || true)}"
    if [[ -z "$public_host" || "$public_host" == "localhost" || "$public_host" == "localhost.localdomain" || "$public_host" =~ ^[0-9]+(\.[0-9]+){3}$ || "$public_host" == *:* ]]; then
        log_error "WebAdaptor 注册必须使用可解析的 FQDN，当前值无效: ${public_host:-<空>}"
        return 1
    fi
    local public_base="https://${public_host}"
    [[ "$WEBADAPTOR_PORT" != "443" ]] && public_base+=":${WEBADAPTOR_PORT}"
    local portal_wa_url="${public_base}/${WEBADAPTOR_CONTEXT}/webadaptor"
    local server_wa_url="${public_base}/${SERVER_WEBADAPTOR_CONTEXT}/webadaptor"

    check_server_initialized || { log_error "Server 站点尚未就绪，不能注册 WebAdaptor"; return 1; }
    check_portal_admin_token || { log_error "Portal 管理员认证尚未就绪，不能注册 WebAdaptor"; return 1; }

    register_webadaptor() {
        local mode="$1" wa_url="$2" gateway_url="$3" admin_user="$4" admin_pass="$5" allow_admin="$6"
        local output rc
        local -a cmd=("$wa_tool" -m "$mode" -w "$wa_url" -g "$gateway_url" -u "$admin_user" -p "$admin_pass")
        [[ "$allow_admin" == true ]] && cmd+=(-a true)

        print_subtask "注册 ${mode} WebAdaptor: ${wa_url} ..."
        set +e
        output=$(runuser -u "$GS_USER" -- env HOME="$GS_HOME" JAVA_HOME="$JDK_HOME" \
            PATH="$JDK_HOME/bin:$PATH" "${cmd[@]}" 2>&1)
        rc=$?
        set -e
        printf '%s\n' "$output" >> "$LOG_FILE"

        if (( rc != 0 )); then
            log_error "${mode} WebAdaptor 注册失败（退出码 ${rc}），命令输出: ${output}"
            return 1
        fi
        if grep -qiE 'successfully[[:space:]]+registered|already[[:space:]]+registered|successfully[[:space:]]+configured|already[[:space:]]+configured' <<< "$output"; then
            log_success "${mode} WebAdaptor 注册成功"
        else
            log_warn "${mode} WebAdaptor 命令已执行但未检测到成功标志，请检查日志: ${LOG_FILE}"
        fi
    }

    # Portal 和 Server 必须分别注册；复制 server.war 本身不会完成 Server 注册。
    register_webadaptor portal "$portal_wa_url" "https://${public_host}:${PORTAL_PORT}" \
        "$PORTAL_ADMIN_USER" "$PORTAL_ADMIN_PASS" false
    register_webadaptor server "$server_wa_url" "https://${public_host}:${SERVER_PORT}" \
        "$SITE_ADMIN_USER" "$SITE_ADMIN_PASS" true

    log_success "WebAdaptor 配置完成 [幂等执行]"
}

#==============================================================================
# 安装总结
#==============================================================================
print_summary() {
    local host_ip=$(get_host_ip)
    local fqdn_display="${FQDN:-$host_ip}"

    echo ""
    echo -e "\033[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  GeoScene Enterprise v${SCRIPT_VERSION} 安装完成"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    echo "  安装用户: $GS_USER"
    echo "  安装目录: $GS_BASE"
    echo "  主机 IP:  $host_ip"
    echo "  FQDN:     $fqdn_display"
    echo "  日志文件: $LOG_FILE"
    echo ""
    echo "  访问地址:"
    echo "    Server Manager: https://${fqdn_display}:${SERVER_PORT}/geoscene/manager"
    echo "    Portal:         https://${fqdn_display}:${PORTAL_PORT}/geoscene/home"
    echo "    DataStore:      https://${fqdn_display}:${DATASTORE_PORT}/geoscene/datastore"
    if [[ "$INSTALL_WEBADAPTOR" == true ]]; then
        local wa_base="https://${fqdn_display}"
        [[ "$WEBADAPTOR_PORT" != "443" ]] && wa_base+=":${WEBADAPTOR_PORT}"
        echo "    Portal WebAdaptor: ${wa_base}/${WEBADAPTOR_CONTEXT}"
        echo "    Server WebAdaptor: ${wa_base}/${SERVER_WEBADAPTOR_CONTEXT}"
    fi
    echo ""
    echo "  管理员账户:"
    echo "    Server: $SITE_ADMIN_USER / （密码已隐藏，请从 root-only 凭据文件读取）"
    echo "    Portal: $PORTAL_ADMIN_USER / （密码已隐藏，请从 root-only 凭据文件读取）"
    echo ""
    echo -e "\033[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
}

#==============================================================================
# 主执行流程
#==============================================================================
main() {
    mkdir -p "$(dirname "$LOG_FILE")"; touch "$LOG_FILE"

    echo -e "\033[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[34m  🚀 GeoScene Universal Installer v${SCRIPT_VERSION}\033[0m"
    [[ "$DRY_RUN" == true ]] && echo -e "\033[33m  ⚠️  DRY-RUN 模式\033[0m"
    [[ "$SKIP_CONFIG" == true ]] && echo -e "\033[33m  ⚠️  跳过自动化配置\033[0m"
    echo -e "\033[34m  📋 日志: $LOG_FILE\033[0m"
    echo -e "\033[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

    check_prerequisites
    scan_workspace
    setup_system
    disable_ipv6
    configure_hostname_and_hosts

    # 准备依赖：优先使用 DATA_DIR 中的本地压缩包，缺失时才按 AUTO_DOWNLOAD 下载
    download_and_install_jdk
    download_and_install_tomcat

    create_self_signed_certificate

    # 安装组件（全部必需）
    for comp in server datastore portal webadaptor; do
        [[ -n "${FOUND_INSTALLERS[$comp]+_}" ]] && install_component "$comp" "${FOUND_INSTALLERS[$comp]}"
    done

    copy_license_files

    if [[ "$SKIP_CONFIG" == false ]]; then
        log_host_ip
        print_task_header "自动化配置阶段 [幂等执行]"

        # Server
        start_server
        authorize_server
        create_server_site

        # DataStore
        start_datastore
        configure_datastore

        # Portal
        start_portal
        create_portal
        update_portal_webcontext

        # WebAdaptor（Portal-Server 联合托管请在安装后手动完成）
        configure_webadaptor
    fi

    [[ "$DRY_RUN" == true ]] && log_dry "预演结束" || print_summary
}

#==============================================================================
# 安装后健康检查
#==============================================================================
perform_health_check() {
    [[ "$DRY_RUN" == true ]] && return 0

    print_task_header "安装后健康检查"
    local all_passed=true
    local host_ip=$(get_host_ip)
    local health_host="${FQDN:-$host_ip}"

    # 1. Server健康检查
    print_subtask "检查 Server 状态..."
    local server_http
    server_http=$(curl -sk -o /dev/null -w '%{http_code}' \
        "https://${health_host}:${SERVER_PORT}/geoscene/rest/info?f=pjson" 2>/dev/null || true)
    if [[ "$server_http" == "200" ]]; then
        print_subtask_success "Server API 正常"
        local token=$(curl -sk -X POST "https://${health_host}:${SERVER_PORT}/geoscene/admin/generateToken" \
            -d "username=$SITE_ADMIN_USER" -d "password=$SITE_ADMIN_PASS" \
            -d "client=requestip" -d "f=json" 2>/dev/null | grep -oP '"token":"[^"]+' | cut -d'"' -f4)
        [[ -n "$token" ]] && print_subtask_success "Server 授权正常" || print_subtask_warn "Server 授权可能有问题"
    else
        print_subtask_error "Server API 状态异常（HTTP ${server_http:-000}）"
        all_passed=false
    fi

    # 2. Portal健康检查
    print_subtask "检查 Portal 状态..."
    local portal_http
    portal_http=$(curl -sk -o /dev/null -w '%{http_code}' \
        "https://${health_host}:${PORTAL_PORT}/geoscene/sharing/rest/info?f=json" 2>/dev/null || true)
    if [[ "$portal_http" == "200" ]]; then
        print_subtask_success "Portal API 正常"
    else
        print_subtask_error "Portal API 状态异常（HTTP ${portal_http:-000}）"
        all_passed=false
    fi

    # 3. DataStore健康检查
    print_subtask "检查 DataStore 状态..."
    local datastore_http
    datastore_http=$(curl -skL -o /dev/null -w '%{http_code}' \
        "https://${health_host}:${DATASTORE_PORT}/geoscene/datastore?f=json" 2>/dev/null || true)
    if [[ "$datastore_http" == "200" ]]; then
        print_subtask_success "DataStore API 正常"
    else
        print_subtask_warn "DataStore API 状态异常（HTTP ${datastore_http:-000}）"
    fi

    # 4. WebAdaptor context 检查：端口监听不代表两个 WAR 都已部署。
    if [[ "$INSTALL_WEBADAPTOR" == true ]]; then
        local wa_host="${FQDN:-$host_ip}"
        local wa_base="https://${wa_host}"
        [[ "$WEBADAPTOR_PORT" != "443" ]] && wa_base+=":${WEBADAPTOR_PORT}"
        local context code
        for context in "$WEBADAPTOR_CONTEXT" "$SERVER_WEBADAPTOR_CONTEXT"; do
            code=$(curl -sk -o /dev/null -w '%{http_code}' "${wa_base}/${context}/" 2>/dev/null || true)
            if [[ "$code" =~ ^(200|301|302|401|403)$ ]]; then
                print_subtask_success "WebAdaptor /${context} 可访问（HTTP ${code}）"
            else
                print_subtask_error "WebAdaptor /${context} 不可访问（HTTP ${code:-000}）"
                all_passed=false
            fi
        done
    fi

    # 5. 系统资源检查
    print_subtask "检查系统资源..."
    local ram_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
    local disk_avail=$(df -h "$GS_HOME" 2>/dev/null | awk 'NR==2{print $4}')
    print_subtask_success "内存: ${ram_mb}MB, 磁盘: $disk_avail"

    [[ "$all_passed" == true ]] && log_success "所有健康检查通过" || log_warn "部分检查未通过"
}

#==============================================================================
# systemd服务管理
#==============================================================================
setup_systemd_services() {
    [[ "$DRY_RUN" == true ]] && return 0

    print_task_header "配置 systemd 服务"

    local server_home portal_home datastore_home
    server_home=$(gs_component_home server)
    portal_home=$(gs_component_home portal)
    datastore_home=$(gs_component_home datastore)

    cat > /etc/systemd/system/geosceneserver.service << EOF
[Unit]
Description=GeoScene Enterprise Server
After=network.target
[Service]
Type=oneshot
RemainAfterExit=true
User=$GS_USER
Group=$GS_GROUP
Environment=HOME=$GS_HOME
ExecStart=$server_home/startserver.sh
ExecStop=$server_home/stopserver.sh
    GuessMainPID=false
    LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/geosceneportal.service << EOF
[Unit]
Description=GeoScene Enterprise Portal
After=network.target geosceneserver.service
[Service]
Type=oneshot
RemainAfterExit=true
User=$GS_USER
Group=$GS_GROUP
Environment=HOME=$GS_HOME
ExecStart=$portal_home/startportal.sh
ExecStop=$portal_home/stopportal.sh
    GuessMainPID=false
    LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/geoscenedatastore.service << EOF
[Unit]
Description=GeoScene Enterprise DataStore
After=network.target geosceneserver.service
[Service]
Type=oneshot
RemainAfterExit=true
User=$GS_USER
Group=$GS_GROUP
Environment=HOME=$GS_HOME
ExecStart=$datastore_home/startdatastore.sh
ExecStop=$datastore_home/stopdatastore.sh
    GuessMainPID=false
    LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

    if [[ "$INSTALL_WEBADAPTOR" == true ]]; then
        cat > /etc/systemd/system/geoscene-tomcat.service << EOF
[Unit]
Description=GeoScene WebAdaptor Tomcat
After=network.target geosceneserver.service geosceneportal.service
[Service]
Type=simple
User=$GS_USER
Group=$GS_GROUP
Environment=HOME=$GS_HOME
Environment=JAVA_HOME=$JDK_HOME
Environment=CATALINA_HOME=$TOMCAT_HOME
Environment=CATALINA_PID=$TOMCAT_HOME/temp/tomcat.pid
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
ExecStart=$TOMCAT_HOME/bin/catalina.sh run
ExecStop=/bin/kill -TERM \$MAINPID
KillMode=process
Restart=on-failure
RestartSec=15
[Install]
WantedBy=multi-user.target
EOF
    fi

    chmod 644 /etc/systemd/system/geosceneserver.service /etc/systemd/system/geosceneportal.service /etc/systemd/system/geoscenedatastore.service
    [[ -f /etc/systemd/system/geoscene-tomcat.service ]] && chmod 644 /etc/systemd/system/geoscene-tomcat.service
    systemctl daemon-reload
    systemctl enable geosceneserver.service geosceneportal.service geoscenedatastore.service
    [[ "$INSTALL_WEBADAPTOR" == true ]] && systemctl enable geoscene-tomcat.service
    # Keep service state consistent with the vendor start scripts used above.
    systemctl reset-failed geosceneserver.service geosceneportal.service geoscenedatastore.service 2>/dev/null || true
    systemctl start geosceneserver.service geosceneportal.service geoscenedatastore.service

    log_success "systemd 服务配置完成"
}

#==============================================================================
# 性能调优
#==============================================================================
apply_performance_tuning() {
    [[ "$DRY_RUN" == true ]] && return 0

    print_task_header "应用性能调优"

    # JVM参数优化
    local tomcat_setenv="$TOMCAT_HOME/bin/setenv.sh"
    cat > "$tomcat_setenv" << EOF
#!/bin/bash
export CATALINA_OPTS="-server -Xms2g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
export JAVA_OPTS="-Djava.security.egd=file:/dev/./urandom"
EOF
    chmod +x "$tomcat_setenv"
    chown "$GS_USER:$GS_GROUP" "$tomcat_setenv"

    # 内核参数优化（独立 drop-in，避免重复追加 /etc/sysctl.conf）
    cat > /etc/sysctl.d/99-geoscene.conf << EOF
# GeoScene Performance Tuning
vm.swappiness=1
vm.dirty_ratio=40
vm.max_map_count=262144
net.core.somaxconn=65535
EOF
    sysctl --load=/etc/sysctl.d/99-geoscene.conf &>/dev/null || true

    log_success "性能调优应用完成"
}

#==============================================================================
# 日志管理
#==============================================================================
setup_log_management() {
    [[ "$DRY_RUN" == true ]] && return 0

    print_task_header "配置日志管理"

    local server_home portal_home datastore_home
    server_home=$(gs_component_home server)
    portal_home=$(gs_component_home portal)
    datastore_home=$(gs_component_home datastore)

    # logrotate配置
    cat > /etc/logrotate.d/geoscene << EOF
$server_home/usr/logs/*.log $portal_home/usr/logs/*.log $datastore_home/usr/logs/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    create 644 $GS_USER $GS_GROUP
}
EOF

    # 日志收集脚本
    cat > "$GS_BASE/collect-logs.sh" << EOF
#!/bin/bash
OUTPUT_DIR="/tmp/geoscene-logs-\$(date +%Y%m%d-%H%M%S)"
mkdir -p "\$OUTPUT_DIR"
cp -r /var/log/geoscene*.log "\$OUTPUT_DIR/" 2>/dev/null || true
[[ -d "$server_home/usr/logs" ]] && cp -r "$server_home/usr/logs" "\$OUTPUT_DIR/server" 2>/dev/null || true
[[ -d "$portal_home/usr/logs" ]] && cp -r "$portal_home/usr/logs" "\$OUTPUT_DIR/portal" 2>/dev/null || true
[[ -d "$datastore_home/usr/logs" ]] && cp -r "$datastore_home/usr/logs" "\$OUTPUT_DIR/datastore" 2>/dev/null || true
tar -czf "\${OUTPUT_DIR}.tar.gz" -C "\$(dirname "\$OUTPUT_DIR")" "\$(basename "\$OUTPUT_DIR")"
rm -rf "\$OUTPUT_DIR"
echo "日志已收集: \${OUTPUT_DIR}.tar.gz"
EOF
    chmod +x "$GS_BASE/collect-logs.sh"
    chown "$GS_USER:$GS_GROUP" "$GS_BASE/collect-logs.sh"

    log_success "日志管理配置完成"
}

#==============================================================================
# 修改主函数，添加新功能调用
#==============================================================================
main_with_enhancements() {
    mkdir -p "$(dirname "$LOG_FILE")"; touch "$LOG_FILE"

    echo -e "\033[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[34m  🚀 GeoScene Universal Installer v${SCRIPT_VERSION}\033[0m"
    [[ "$DRY_RUN" == true ]] && echo -e "\033[33m  ⚠️  DRY-RUN 模式\033[0m"
    echo -e "\033[34m  📋 日志: $LOG_FILE\033[0m"
    echo -e "\033[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

    # 创建备份
    create_backup
    prepare_reinstall

    check_prerequisites
    scan_workspace
    setup_system
    disable_ipv6
    configure_hostname_and_hosts

    # 准备依赖：优先使用 DATA_DIR 中的本地压缩包，缺失时才按 AUTO_DOWNLOAD 下载
    download_and_install_jdk
    download_and_install_tomcat

    create_self_signed_certificate

    # 安装组件
    for comp in server datastore portal webadaptor; do
        [[ -n "${FOUND_INSTALLERS[$comp]+_}" ]] && install_component "$comp" "${FOUND_INSTALLERS[$comp]}"
    done

    copy_license_files

    if [[ "$SKIP_CONFIG" == false ]]; then
        log_host_ip
        print_task_header "自动化配置阶段 [幂等执行]"

        start_server
        authorize_server
        create_server_site
        start_datastore
        configure_datastore
        start_portal
        create_portal
        # Create the Tomcat unit before WebAdaptor startup so the service can
        # bind HTTPS port 443 with its narrowly-scoped capability.
        setup_systemd_services
        configure_webadaptor
        update_portal_webcontext

        # 新增功能
        apply_performance_tuning
        setup_log_management
    fi

    # 健康检查
    perform_health_check

    [[ "$DRY_RUN" == true ]] && log_dry "预演结束" || print_summary
}

# 执行主程序
main_with_enhancements "$@"
