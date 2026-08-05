# GeoScene Enterprise 全自动化安装部署工具 (v7.0)

自动安装部署 GeoScene Enterprise (Server + Portal + DataStore + WebAdaptor)，支持一键安装、授权、站点创建、门户初始化、DataStore 配置、主机名配置、域名映射、证书管理、WebAdaptor 自动安装、JDK/Tomcat 自动下载安装、多平台支持、幂等执行；Portal-Server 联合托管在安装后手动完成。

> 完整的架构、脚本职责、安装/卸载、WebAdaptor、联合托管和排障说明见 [GEOSCENE_SYSTEM_GUIDE.md](GEOSCENE_SYSTEM_GUIDE.md)。

## 更新记录

- **2026-08-05**：合并 GeoScene 6.1 实机验证后的安装、卸载、IPv6、FQDN、证书、systemd、健康检查和日志管理更新；Portal 与 Server WebAdaptor 现在会分别自动部署和注册。Portal-Server 联合托管仍保留为安装后的手动步骤。
- **安全提醒**：仓库中的 `geoscene.conf` 只包含占位密码。生产部署前必须替换管理员密码、证书密码，并将配置文件权限设置为 `600`。

## 版本 7.0 新增功能

### 核心功能
- **JDK/Tomcat 自动下载安装** - 从 Adoptium/Apache 官方源自动下载安装 (优先 JDK 17)
- **幂等执行** - 重复运行自动检测并更新现有配置，无需担心重复执行
- **多平台适配** - 可识别常见 Linux 的包管理器；具体 GeoScene 6.1 是否认证，仍以产品支持矩阵为准
- **架构检查** - 自动验证安装包与系统架构匹配，拒绝 Windows 安装包
- **Tomcat 安全加固** - 自动应用安全配置（禁用不安全端口、禁用示例应用）
- **增强异常处理** - 自动重试机制和错误恢复

### 运维增强
- **安装前配置验证** - 验证 FQDN 格式、密码强度、端口范围、邮箱格式、磁盘空间等
- **安装后健康检查** - 自动验证所有组件 API 连通性、授权状态、证书有效性、系统资源
- **systemd 服务管理** - 创建系统服务文件，支持 systemctl 启停管理
- **备份与回滚机制** - 安装前自动备份配置，失败时可回滚
- **性能调优** - JVM 参数优化、内核参数调优、Tomcat 线程池配置
- **日志管理** - 日志轮转配置 (logrotate)、日志收集脚本、日志清理脚本

## 版本 6.0 功能回顾

- **主机名/FQDN 自动配置** - 解决 localhost 跳转问题
- **/etc/hosts 域名映射配置** - 确保内部通信使用正确域名
- **SystemD system.conf 限制配置** - 符合官方要求
- **自签名 SSL 证书自动创建** - 用于 HTTPS 配置
- **WebAdaptor 自动安装配置** - 提供 443 端口反向代理

## 目录结构

```
installgeoscene/
├── install-geoscene.sh              # 安装脚本 (v7.0)
├── uninstall-geoscene.sh            # 卸载脚本 (v7.0)
├── geoscene.conf                    # 配置文件模板 (强烈推荐使用)
├── README.md                        # 本文档
│
├── DATA_DIR/                        # 可选：本地安装包和 JDK/Tomcat 压缩包目录
├── GeoScene_Server_Linux_*.tar.gz   # Server 安装包
├── GeoScene_Portal_Linux_*.tar.gz   # Portal 安装包
├── GeoScene_DataStore_Linux_*.tar.gz # DataStore 安装包
├── GeoScene_Web_Adaptor_java_Linux_*.tar.gz # WebAdaptor 安装包
│
├── *.prvc                           # Server 授权文件 (自动化配置必需)
├── *.ecp                            # Server/Enterprise 授权文件 (自动化配置必需)
└── *portal*.json 或 *enterprise*.json # Portal 授权文件 (自动化配置必需)
```

## 快速开始

### 1. 准备安装文件

安装包可以放在脚本同目录，也可以通过 `DATA_DIR`/`--data-dir` 指定目录。缺少 JDK/Tomcat 压缩包时，`AUTO_DOWNLOAD=true` 会尝试联网下载；生产环境建议提前准备经过验证的本地包，或显式配置 `JDK_HOME`、`TOMCAT_HOME` 并设置 `AUTO_DOWNLOAD=false`。

```bash
# 本地安装包（推荐放入 DATA_DIR；版本号按实际安装包填写）
GeoScene_Server_Linux_41_*.tar.gz
GeoScene_Portal_Linux_41_*.tar.gz
GeoScene_DataStore_Linux_41_*.tar.gz   # 必需
GeoScene_Web_Adaptor_java_Linux_41_*.tar.gz  # 必需

# 授权文件 (自动化配置必需)
GeoSceneServerAdvanced_GeoSceneServer_*.prvc    # Server 授权 (*.prvc)
authorization_geoscene_*.ecp                    # Server 授权 (*.ecp)
GeoScene_Enterprise_Portal_*.json               # Portal 授权
```

### 2. 创建配置文件（推荐）

```bash
# 编辑配置文件
nano geoscene.conf
```

**关键配置：FQDN（强烈建议配置）**

```bash
# geoscene.conf - 生产环境推荐配置

# 基础配置
GS_USER=geoscene
GS_GROUP=geoscene
GS_HOME=/home/geoscene
GS_BASE=/home/geoscene/geoscene

# 端口配置
SERVER_PORT=6443
PORTAL_PORT=7443
DATASTORE_PORT=2443

# === 主机名和域名配置（关键！解决localhost跳转问题）===
FQDN=portal.geosceneenterprise.cn
HOSTNAME=portal
CONFIGURE_HOSTNAME=true
CONFIGURE_HOSTS=true
DISABLE_IPV6=true

# 管理员账户配置
SITE_ADMIN_USER=siteadmin
SITE_ADMIN_PASS=YourPassword123
PORTAL_ADMIN_USER=portaladmin
PORTAL_ADMIN_PASS=YourPassword123
PORTAL_ADMIN_EMAIL=portaladmin@example.com
PORTAL_ADMIN_FN=Admin
PORTAL_ADMIN_LN=User
PORTAL_ADMIN_QI=1
PORTAL_ADMIN_QA=Beijing

# WebAdaptor配置 (必需组件，自动下载JDK/Tomcat)
INSTALL_WEBADAPTOR=true
TOMCAT_VERSION=9.0.89
TOMCAT_HOME=/opt/tomcat
JDK_VERSION=17
JDK_HOME=/opt/jdk
WEBADAPTOR_PORT=443

# 证书配置
CREATE_SELF_SIGNED_CERT=true

# 自动下载配置 (v7.0)
AUTO_DOWNLOAD=true

# 资源要求
MIN_RAM_MB=8192
MIN_CPU_CORES=4
MIN_DISK_HOME_GB=20
MIN_DISK_INSTALL_GB=30
```

### 3. 执行安装

```bash
# 使用配置文件全自动安装（推荐）
bash install-geoscene.sh --config=geoscene.conf

# 指定FQDN进行安装（解决localhost跳转问题）
bash install-geoscene.sh --fqdn=portal.geosceneenterprise.cn

# 预演模式 (检查但不执行)
bash install-geoscene.sh --dry-run

# 跳过主机名配置（如果已手动配置）
bash install-geoscene.sh --skip-hostname
```

## 配置变量详解

所有变量均可通过配置文件覆盖，优先级：命令行参数 > 配置文件 > 默认值

### 用户和目录配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `GS_USER` | `geoscene` | GeoScene 运行用户 |
| `GS_GROUP` | `geoscene` | 用户所属组 |
| `GS_HOME` | `/home/geoscene` | 用户 home 目录 |
| `GS_BASE` | `/home/geoscene/geoscene` | 安装基础目录 |

### 主机名和域名配置（关键！）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `FQDN` | `` | 完全限定域名，如 `portal.geosceneenterprise.cn` |
| `HOSTNAME` | `` | 主机名，如 `portal` |
| `CONFIGURE_HOSTNAME` | `true` | 是否配置 `/etc/hostname` |
| `CONFIGURE_HOSTS` | `true` | 是否配置 `/etc/hosts` |
| `DISABLE_IPV6` | `true` | 是否禁用IPv6并确保 `localhost` 解析为 `127.0.0.1` |

**为什么需要 FQDN？**

根据官方文档，GeoScene Enterprise 安装计算机名必须是完全限定域名(FQDN)形式。如果不正确配置，Portal 内部会跳转至 localhost，导致浏览器访问失败。脚本会自动配置主机名和 hosts 映射，避免此问题。

### 端口配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SERVER_PORT` | `6443` | Server HTTPS 端口 |
| `PORTAL_PORT` | `7443` | Portal HTTPS 端口 |
| `DATASTORE_PORT` | `2443` | DataStore HTTPS 端口 |

### JDK/Tomcat 配置（v7.0 自动下载）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `JDK_VERSION` | `17` | JDK 版本 (17/11/8, GeoScene 4.1 支持 17) |
| `JDK_HOME` | `/opt/jdk` | JDK 安装目录 (自动下载安装) |
| `TOMCAT_VERSION` | `9.0.89` | Tomcat 版本 |
| `TOMCAT_HOME` | `/opt/tomcat` | Tomcat 安装目录 (自动下载安装) |
| `AUTO_DOWNLOAD` | `true` | 是否自动下载缺失的依赖 |

**JDK 版本说明：**
- GeoScene Enterprise 4.1 支持 JDK 17（推荐）
- 脚本会自动从 Adoptium (Eclipse Temurin) 下载安装
- 支持 x86_64 和 aarch64 (ARM64) 架构

### WebAdaptor 配置（必需组件）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `INSTALL_WEBADAPTOR` | `true` | 是否安装 WebAdaptor |
| `WEBADAPTOR_PORT` | `443` | WebAdaptor 端口 |
| `WEBADAPTOR_CONTEXT` | `geoscene` | WebAdaptor 上下文 |
| `SERVER_WEBADAPTOR_CONTEXT` | `server` | Server WebAdaptor 上下文 |

### 证书配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CREATE_SELF_SIGNED_CERT` | `true` | 是否创建自签名证书 |
| `CERT_COUNTRY` | `CN` | 证书国家代码 |
| `CERT_STATE` | `Beijing` | 证书省份 |
| `CERT_CITY` | `Beijing` | 证书城市 |
| `CERT_ORG` | `GeoScene` | 证书组织 |
| `CERT_OU` | `Product Department` | 证书部门 |
| `CERT_EMAIL` | `admin@geoscene.cn` | 证书邮箱 |
| `CERT_DAYS` | `3650` | 证书有效期(天) |
| `CERT_PASSWORD` | `geoscene` | 证书密码 |

### 管理员账户配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SITE_ADMIN_USER` | `siteadmin` | Server 站点管理员用户名 |
| `SITE_ADMIN_PASS` | `YourPassword123` | Server 站点管理员密码 |
| `PORTAL_ADMIN_USER` | `portaladmin` | Portal 管理员用户名 |
| `PORTAL_ADMIN_PASS` | `YourPassword123` | Portal 管理员密码 |
| `PORTAL_ADMIN_EMAIL` | `portaladmin@example.com` | Portal 管理员邮箱 |
| `PORTAL_ADMIN_FN` | `Admin` | Portal 管理员名 |
| `PORTAL_ADMIN_LN` | `User` | Portal 管理员姓 |
| `PORTAL_ADMIN_QI` | `1` | Portal 安全问题 ID |
| `PORTAL_ADMIN_QA` | `Beijing` | Portal 安全问题答案 |

### 系统资源要求

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `MIN_RAM_MB` | `8192` | 最小内存要求 (MB) |
| `MIN_CPU_CORES` | `4` | 最小 CPU 核数 |
| `MIN_DISK_HOME_GB` | `20` | home 目录最小磁盘 (GB) |
| `MIN_DISK_INSTALL_GB` | `30` | 安装目录最小磁盘 (GB) |

## 安装脚本选项

| 选项 | 说明 |
|------|------|
| `-h, --help` | 显示帮助信息 |
| `--man` | 显示完整手册页 |
| `-n, --dry-run` | 预演模式，不执行实际变更 |
| `--config=FILE` | 指定配置文件 |
| `--skip-config` | 仅安装软件，跳过站点配置 |
| `--skip-hostname` | 跳过主机名和hosts配置 |
| `--disable-ipv6` | 禁用IPv6，确保localhost使用IPv4 |
| `--gs-user=USER` | GeoScene 运行用户 |
| `--gs-base=DIR` | 安装基础目录 |
| `--fqdn=DOMAIN` | 设置 FQDN |
| `--hostname=NAME` | 设置主机名 |
| `--jdk-version=VERSION` | JDK 版本 (17/11/8) |
| `--tomcat-version=VER` | Tomcat 版本 |
| `--create-cert` | 创建自签名证书 |

## 自动化工作流程

安装脚本自动执行以下步骤（v7.0）：

```
1. 前置校验
   ├─ 权限检查 (root)
   ├─ 资源检查 (内存 ≥MIN_RAM_MB, 磁盘 ≥MIN_DISK_HOME_GB)
   ├─ 端口检查 (SERVER_PORT, PORTAL_PORT, DATASTORE_PORT, 9876, 9877, 443)
   ├─ 架构检查 (x86_64/arm64)
   ├─ 平台检查 (拒绝 Windows 安装包)
   └─ 自动检测服务器 IP

2. 系统配置 (幂等执行)
   ├─ 创建 GS_USER 用户和 GS_GROUP 组
   ├─ 配置 limits.conf (nofile=65536, nproc=25059) [幂等更新]
   ├─ 配置 systemd system.conf [幂等更新]
   ├─ 开放防火墙端口
   └─ 配置 hostname 和 hosts [幂等更新]

3. 自动下载依赖
   ├─ 下载 Adoptium JDK (优先 17, 备选 11/8)
   └─ 下载 Apache Tomcat (9.0.89)

4. 证书创建
   └─ 创建自签名 SSL 证书 (用于 WebAdaptor HTTPS)

5. Tomcat 安全加固
   ├─ 删除示例应用
   ├─ 禁用 8080 HTTP 端口
   ├─ 禁用 AJP 连接器
   └─ 配置 HTTPS 连接器

6. 软件安装 (幂等执行)
   ├─ 解压安装包
   ├─ 执行静默安装 (Setup -m silent -l yes)
   ├─ 架构检查 (安装包 vs 系统)
   └─ 平台检查 (拒绝 Windows 包)

7. Server 授权 (幂等执行)
   └─ 执行 authorizeSoftware -f license.ecp/prvc

8. Server 站点创建 (幂等执行)
   └─ 执行 createsite.sh 创建站点

9. DataStore 配置 (幂等执行)
   ├─ 确保 PublishingTools 服务启动
   └─ 执行 configuredatastore.sh 注册到 Server

10. Portal 门户创建 (幂等执行)
    └─ 执行 createportal.sh 创建门户并导入授权

11. Portal WebContextURL 更新
    └─ 更新为实际 IP/FQDN，避免 localhost 问题

12. WebAdaptor 安装配置 (幂等执行)
    ├─ 部署 war 到 Tomcat
    ├─ 配置 HTTPS 连接器
    └─ 应用安全加固

13. 证书导入
    └─ 导入证书到 Server 和 Portal

    └─ 配置 Portal 托管 Server 服务
```

**流程顺序**: Server → DataStore → Portal → WebAdaptor（分别注册 Portal/Server）；Portal-Server 联合托管请安装后手动完成

DataStore 必须先注册到 Server，才能支持 Portal 的托管服务功能。

## 幂等执行说明

脚本支持幂等执行，重复运行会自动：

1. **检测现有配置并更新**
   - `limits.conf`: 检查现有配置并更新为需要的值 (nofile=65536, nproc=25059)
   - `systemd system.conf`: 检查并更新 DefaultLimitNOFILE/DefaultLimitNPROC
   - `/etc/hostname`: 如果不同则更新
   - `/etc/hosts`: 如果 IP 或域名映射不同则更新

2. **跳过已完成的步骤**
   - 已安装组件自动跳过
   - 已授权 Server 自动跳过
   - 已创建站点自动跳过
   - 已配置 DataStore 自动跳过

3. **自动备份**
   - 更新前自动备份现有配置 (`*.bak.timestamp`)
   - 保留手动配置以供参考

**使用场景：**
```bash
# 首次安装
bash install-geoscene.sh

# 修改配置后重新执行（自动检测并更新变更）
bash install-geoscene.sh --fqdn=newdomain.com
```

## 关键特性

### 1. 主机名/FQDN 自动配置

脚本自动配置 `/etc/hostname` 和 `/etc/hosts`，确保：
- 计算机名使用完全限定域名(FQDN)
- IP 地址正确映射到域名
- 避免 Portal 内部跳转至 localhost
- **幂等执行**: 重复运行会检测并更新现有配置

### 2. SystemD 限制配置

自动配置 `/etc/systemd/system.conf`：
- `DefaultLimitNOFILE=65536` - 文件句柄限制
- `DefaultLimitNPROC=25059` - 进程限制
- **幂等执行**: 检测现有配置并更新

### 3. JDK/Tomcat 自动下载安装

- **JDK**: 从 [Adoptium API](https://adoptium.net) 自动下载 Eclipse Temurin
  - 优先 JDK 17（GeoScene 4.1 推荐）
  - 支持 x86_64 和 aarch64 架构
  - 自动配置 `JAVA_HOME` 和 `PATH`

- **Tomcat**: 从 [Apache 官方镜像](https://dlcdn.apache.org) 自动下载
  - 默认版本 9.0.89
  - 自动解压并配置
  - 支持断点续传

- **安全加固**: 自动应用安全配置
  - 删除示例应用
  - 禁用 8080 HTTP
  - 禁用 AJP 连接器
  - 配置 HTTPS 连接器

### 4. 架构检查

自动验证安装包与系统架构匹配：
- 检测系统架构 (x86_64/arm64)
- 验证安装包架构 (从文件名解析)
- 拒绝不匹配的架构 (避免 x86_64 包在 ARM 上安装)

### 5. 平台检查

自动检测并拒绝 Windows 安装包：
- 检测文件名包含 `windows`, `win`, `.exe`, `.msi`
- 拒绝非 Linux 安装包
- 提示用户下载正确的 Linux 版本

### 6. 多平台支持

支持多种 Linux 发行版：

| 平台 | 包管理器 |
|------|---------|
| CentOS/RHEL/Rocky/AlmaLinux | yum/dnf |
| Ubuntu/Debian | apt |
| 统信 UOS | apt |
| 银河麒麟 | yum |
| openSUSE | zypper |
| Arch Linux | pacman |

### 7. 实际 IP/FQDN 网络配置

脚本自动检测服务器实际 IP，并将需要对外注册的地址统一使用配置的 FQDN：
- Server/Portal 健康检查使用本机地址
- DataStore 配置使用 `https://<FQDN>:6443`
- WebAdaptor 注册使用 `https://<FQDN>/geoscene/webadaptor` 和 `https://<FQDN>:7443`
- WebContextURL 更新为 FQDN

### 8. PublishingTools 自动启动

DataStore 配置前会自动检查并启动 PublishingTools 服务，确保配置成功。

### 9. Portal WebContextURL 自动更新

Portal 创建后会自动更新 WebContextURL 为实际 IP 地址，并重启 Portal 使配置生效，避免 localhost 问题。

### 10. Portal-Server 联合托管（手动）

安装脚本不再自动调用联合 API。请在 WebAdaptor 配置完成后，按产品管理界面或 REST API 文档手动完成 Portal-Server 联合托管。

## 系统要求

脚本本身不绑定某一个发行版，主要要求目标系统具备 Bash、systemd、常用网络/归档工具以及可用的包管理器。这里的“脚本可运行”不等同于“GeoScene 6.1 已获得官方认证”；生产部署必须同时核对 GeoScene 6.1 的操作系统、补丁级别和 CPU 架构支持矩阵。

| 项目 | 要求 |
|------|------|
| 操作系统 | Linux（systemd）；麒麟 V10、Ubuntu、RHEL/Rocky 等需按 GeoScene 6.1 支持矩阵确认 |
| 架构 | x86_64 或 aarch64 (ARM64)；海光 C86 主机通常按 x86_64 检查 |
| 内存 | ≥ 8GB (生产环境推荐 16GB+) |
| CPU | ≥ 4核 |
| 磁盘 | ≥ 20GB (安装目录) + ≥ 30GB (数据目录) |
| 端口 | 6443, 7443, 2443, 9876, 9877, 443 可用 |
| 网络 | 可访问互联网（用于下载 JDK/Tomcat） |
| 权限 | root |
| 主机名 | **不能包含下划线** (_)，建议使用 FQDN |

说明：CentOS Linux 8 已结束生命周期，不建议新建生产部署；如果使用 CentOS 系列，优先选择仍受维护且被 GeoScene 6.1 支持矩阵覆盖的 RHEL/Rocky 等替代发行版。海光 C86 机器先执行 `uname -m`，若返回 `x86_64` 就使用 x86_64 安装包；ARM 机器必须使用 aarch64/ARM64 安装包，不能混用。

## 安装结果

安装完成后，可通过以下地址访问（使用实际 IP）：

| 服务 | 地址 |
|------|------|
| Server Manager | `https://<IP>:6443/geoscene/manager` |
| Server REST | `https://<IP>:6443/geoscene/rest/services` |
| Portal | `https://<IP>:7443/geoscene/home` |
| Portal Admin | `https://<IP>:7443/geoscene/portaladmin` |
| DataStore | `https://<IP>:2443/geoscene/datastore` |

如果使用 WebAdaptor（配置了 FQDN）：

| 服务 | 地址 |
|------|------|
| Portal (via WA) | `https://<FQDN>/geoscene` |
| Server (via WA) | `https://<FQDN>/server` |

## 日志文件

- 安装日志: `/var/log/geoscene_YYYYMMDD_HHMMSS.log`
- 状态记录: `/var/log/.geoscene_install_state`

## 常见问题

### Q: 如何解决 localhost 跳转问题？

A: 配置正确的 FQDN：
1. 在配置文件中设置 `FQDN=yourdomain.com`
2. 设置 `CONFIGURE_HOSTNAME=true` 和 `CONFIGURE_HOSTS=true`
3. 确保 DNS 或 hosts 文件正确解析域名到 IP
4. 脚本会自动更新 WebContextURL 为实际 IP/FQDN

### Q: JDK/Tomcat 下载失败怎么办？

A: 检查以下项：
1. 确保服务器有互联网访问权限
2. 检查防火墙是否阻止了下载
3. 手动下载并放置在指定目录
4. 如果已经手动安装，请在配置中设置 `JDK_HOME`、`TOMCAT_HOME` 和 `AUTO_DOWNLOAD=false`；`--skip-config` 只跳过站点配置，不会关闭依赖准备流程

### Q: 如何手动安装 JDK/Tomcat？

A: 如果不希望自动下载：
1. 下载 Adoptium JDK 17: https://adoptium.net
2. 下载 Tomcat 9.0: https://tomcat.apache.org
3. 解压到指定目录 (`JDK_HOME`, `TOMCAT_HOME`)
4. 设置 `AUTO_DOWNLOAD=false`

### Q: 授权文件命名规则？

A: 授权文件匹配规则：
- **Server 授权**: 
  - `.prvc` 文件：任意命名都会被识别为 Server 授权
  - `.ecp` 文件：任意命名都会被识别为 Server/Enterprise 授权
  - 示例：`GeoSceneServerAdvanced_*.prvc`、`authorization_geoscene_*.ecp`
- **Portal 授权**: 
  - `.json` 文件：文件名需包含 `portal` 或 `enterprise` 关键字
  - 示例：`GeoScene_Enterprise_Portal_*.json`、`portal_license.json`

**注意**: 如果同时存在多个授权文件，脚本会选择第一个匹配的。建议只保留一个 Server 授权和一个 Portal 授权。

### Q: 架构不匹配怎么办？

A: 如果脚本提示架构不匹配：
1. 检查系统架构: `uname -m`
2. 下载匹配架构的安装包:
   - x86_64: `*_Linux_x64_*.tar.gz` 或 `*_Linux_x86_64_*.tar.gz`
   - ARM64: `*_Linux_arm64_*.tar.gz` 或 `*_Linux_aarch64_*.tar.gz`
3. 确保没有混合不同架构的安装包

### Q: 为什么检测到 Windows 安装包？

A: 脚本会检测文件名包含 `windows`, `win`, `.exe`, `.msi` 的安装包并拒绝。
请下载正确的 Linux 版本：
- Server: `GeoScene_Server_Linux_41_*.tar.gz`
- Portal: `GeoScene_Portal_Linux_41_*.tar.gz`
- DataStore: `GeoScene_DataStore_Linux_41_*.tar.gz`
- WebAdaptor: `GeoScene_Web_Adaptor_java_Linux_41_*.tar.gz`

### Q: 如何配置 Portal-Server 联合托管？

A: 安装脚本不会自动执行联合。请手动配置：
1. 登录 Portal: `https://<IP>:7443/geoscene/home`
2. 平台管理 → 系统配置 → 服务器 → 添加服务器
3. 输入 Server URL 和 Admin URL
4. 输入 Server 管理员账户
5. 设置为托管服务器

### Q: 自签名证书和 CA 证书有什么区别？

A:
- **自签名证书**: 脚本自动生成，浏览器会提示不安全，适合测试环境
- **CA 证书**: 由可信证书颁发机构签发，浏览器信任，适合生产环境

生产环境建议使用由组织 CA 签发的证书，或使用 Let's Encrypt 等免费证书。

### Q: 如何跳过主机名配置？

A: 如果已手动配置好主机名和 hosts：
```bash
bash install-geoscene.sh --skip-hostname
```
或在配置文件中设置：
```bash
CONFIGURE_HOSTNAME=false
CONFIGURE_HOSTS=false
```

### Q: 如何查看帮助信息？

```bash
# 简要帮助
bash install-geoscene.sh --help

# 完整手册
bash install-geoscene.sh --man
```

### Q: 如何彻底卸载？

```bash
# 安全卸载 (保留数据目录)
bash uninstall-geoscene.sh

# 彻底清理 (删除所有数据)
bash uninstall-geoscene.sh --purge

# 强制彻底清理 (忽略错误)
bash uninstall-geoscene.sh --purge --force

# 在彻底清理的基础上删除安装备份和日志
bash uninstall-geoscene.sh --purge --remove-backups --remove-logs
```

### Q: 如何查看安装后的健康状态？

A: 脚本会在安装完成后自动执行健康检查，也可以手动检查：

```bash
# 查看服务状态
systemctl status geosceneserver
systemctl status geosceneportal
systemctl status geoscenedatastore
systemctl status geoscene-tomcat

# 收集日志
bash /home/geoscene/geoscene/collect-logs.sh

# 查看健康报告
cat /var/log/geoscene_health_*.txt
```

### Q: 如何管理服务？

A: v7.0 自动配置了 systemd 服务：

```bash
# 启动所有服务
systemctl start geosceneserver geosceneportal geoscenedatastore geoscene-tomcat

# 停止所有服务
systemctl stop geosceneserver geosceneportal geoscenedatastore geoscene-tomcat

# 重启服务
systemctl restart geosceneserver

# 查看状态
systemctl status geosceneserver geosceneportal geoscenedatastore geoscene-tomcat

# 设置开机自启
systemctl enable geosceneserver geosceneportal geoscenedatastore geoscene-tomcat
```

### Q: 安装失败如何回滚？

A: v7.0 在安装前会自动创建备份：

```bash
# 查看备份目录
ls -la /home/geoscene/.geoscene_backup/

# 手动回滚（如果需要）
cp /home/geoscene/.geoscene_backup/YYYYMMDD_HHMMSS/hosts /etc/hosts
cp /home/geoscene/.geoscene_backup/YYYYMMDD_HHMMSS/hostname /etc/hostname
systemctl daemon-reload
```

### Q: 如何清理日志？

A: 使用自动生成的清理脚本：

```bash
# 清理30天前的日志
bash /home/geoscene/geoscene/cleanup-logs.sh

# 手动清理
find /home/geoscene/geoscene -name "*.log" -mtime +30 -delete
```

### Q: 配置验证失败怎么办？

A: 常见验证错误及解决：

1. **密码强度不足**: 密码必须≥8位，包含大小写字母和数字
2. **FQDN格式错误**: 使用正确的域名格式，如 `portal.company.com`
3. **端口被占用**: 检查并释放端口，或修改配置文件使用其他端口
4. **磁盘空间不足**: 确保至少有 60GB 可用空间 (20GB安装+30GB数据+10GB缓冲)
5. **内存不足**: 建议至少 8GB 内存，生产环境推荐 16GB+

## 卸载脚本选项

| 选项 | 说明 |
|------|------|
| `-h, --help` | 显示帮助信息 |
| `--man` | 显示完整手册页 |
| `-f, --purge` | 彻底删除所有数据目录 |
| `-s, --silent` | 调用 GeoScene 官方静默卸载器 |
| `--force` | 强制模式，忽略单项错误 |
| `--remove-backups` | 删除安装前备份 |
| `--remove-logs` | 删除安装日志、健康报告和卸载日志 |
| `--config=FILE` | 指定配置文件 |
| `--gs-user=USER` | 指定 GeoScene 运行用户 |
| `--gs-base=DIR` | 指定 GeoScene 安装基础目录 |

默认卸载不会删除 GeoScene 数据、JDK/Tomcat、用户 home、备份或日志；`--purge` 才会清理安装目录、JDK/Tomcat 和用户 home，备份和日志仍需分别使用 `--remove-backups`、`--remove-logs`。
