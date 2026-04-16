# GeoScene Enterprise 全自动化安装部署工具

全自动安装部署 GeoScene Enterprise (Server + Portal + DataStore)，支持一键安装、授权、站点创建、门户初始化、DataStore 配置。使用实际服务器 IP 进行网络配置，避免 localhost 问题。自动化失败时会提示用户浏览器手动处理。

## 目录结构

```
installgeoscene/
├── install-geoscene.sh              # 安装脚本 (v5.0)
├── uninstall-geoscene.sh            # 卸载脚本 (v5.0)
├── geoscene.conf                    # 配置文件模板 (推荐使用)
├── README.md                        # 本文档
│
├── GeoScene_Server_Linux_*.tar.gz   # Server 安装包 (必需)
├── GeoScene_Portal_Linux_*.tar.gz   # Portal 安装包 (必需)
├── GeoScene_DataStore_Linux_*.tar.gz # DataStore 安装包 (可选)
│
├── *.prvc                           # Server 授权文件 (自动化配置必需)
├── *.ecp                            # Server/Enterprise 授权文件 (自动化配置必需)
└── *portal*.json 或 *enterprise*.json # Portal 授权文件 (自动化配置必需)
```

## 快速开始

### 1. 准备安装文件

将以下文件放置在脚本同目录：

```bash
# 安装包 (必需)
GeoScene_Server_Linux_41_*.tar.gz
GeoScene_Portal_Linux_41_*.tar.gz
GeoScene_DataStore_Linux_41_*.tar.gz  # 可选

# 授权文件 (自动化配置必需)
#   Server 授权: *.prvc 或 *.ecp 文件 (文件名可任意，如 authorization_geoscene_*.ecp)
#   Portal 授权: *.json 文件 (文件名需包含 portal 或 enterprise 关键字)
GeoSceneServerAdvanced_GeoSceneServer_*.prvc    # Server 授权 (*.prvc)
authorization_geoscene_*.ecp                    # Server 授权 (*.ecp，Enterprise 授权文件)
GeoScene_Enterprise_Portal_*.json               # Portal 授权
```

### 2. 创建配置文件

```bash
cat > geoscene.conf << 'EOF'
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

# 系统资源要求配置
MIN_RAM_MB=8192
MIN_CPU_CORES=4
MIN_DISK_HOME_GB=20
MIN_DISK_INSTALL_GB=30
EOF
```

### 3. 执行安装

脚本会自动加载 `geoscene.conf` 配置文件，自动检测服务器实际 IP：

```bash
# 全自动化安装 (安装 + 授权 + 创建站点 + 初始化门户 + 配置 DataStore)
bash install-geoscene.sh

# 仅安装软件，跳过自动化配置
bash install-geoscene.sh --skip-config

# 预演模式 (检查但不执行)
bash install-geoscene.sh --dry-run

# 指定其他配置文件
bash install-geoscene.sh --config=my-config.conf
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

### 端口配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SERVER_PORT` | `6443` | Server HTTPS 端口 |
| `PORTAL_PORT` | `7443` | Portal HTTPS 端口 |
| `DATASTORE_PORT` | `2443` | DataStore HTTPS 端口 |

### 管理员账户配置（自动化配置必需）

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
| `--gs-user=USER` | GeoScene 运行用户 |
| `--gs-base=DIR` | 安装基础目录 |

## 卸载脚本选项

| 选项 | 说明 |
|------|------|
| `-h, --help` | 显示帮助信息 |
| `--man` | 显示完整手册页 |
| `-f, --purge` | 彻底删除所有数据目录 |
| `-s, --silent` | 执行静默卸载 |
| `--force` | 强制模式，忽略错误 |

## 自动化工作流程

安装脚本自动执行以下步骤（使用实际服务器 IP）：

```
1. 前置校验
   ├─ 权限检查 (root)
   ├─ 资源检查 (内存 ≥MIN_RAM_MB, 磁盘 ≥MIN_DISK_HOME_GB)
   ├─ 端口检查 (SERVER_PORT, PORTAL_PORT, DATASTORE_PORT, 9876, 9877)
   └─ 自动检测服务器 IP

2. 系统配置
   ├─ 创建 GS_USER 用户和 GS_GROUP 组
   ├─ 配置系统限制 (limits.d)
   └─ 开放防火墙端口

3. 软件安装
   ├─ 解压安装包
   └─ 执行静默安装 (Setup -m silent -l yes)

4. Server 授权 (自动执行)
   ├─ 使用实际 IP 连接 Server
   └─ 执行 authorizeSoftware -f license.ecp/prvc
   └─ 失败时提示浏览器手动处理

5. Server 站点创建 (自动执行)
   ├─ 使用实际 IP 连接 Server
   └─ 执行 createsite.sh 创建站点
   └─ 失败时提示浏览器手动处理

6. DataStore 配置 (自动执行)
   ├─ 启动 DataStore 服务
   ├─ 确保 PublishingTools 服务启动 (关键步骤)
   ├─ 使用实际 IP 连接 Server
   └─ 执行 configuredatastore.sh 注册到 Server
   └─ 失败时提示浏览器手动处理

7. Portal 创建 (自动执行)
   ├─ 启动 Portal 服务
   ├─ 执行 createportal.sh 创建门户并导入授权
   ├─ 更新 Portal WebContextURL (关键步骤)
   ├─ 重启 Portal 使配置生效
   └─ 失败时提示浏览器手动处理
```

**重要**: 流程顺序为 **Server → DataStore → Portal**，DataStore 必须先注册到 Server，才能支持 Portal 的托管服务功能。

## 关键特性

### 1. 实际 IP 网络配置

脚本自动检测服务器实际 IP（如 `10.6.4.22`），所有网络请求使用实际 IP，避免 `localhost` 带来的问题：

- Server 授权/站点创建使用 `https://<实际IP>:6443`
- Portal 创建使用 `https://<实际IP>:7443`
- DataStore 配置使用 `https://<实际IP>:6443`

### 2. PublishingTools 自动启动

DataStore 配置前会自动检查并启动 PublishingTools 服务，确保配置成功。

### 3. PublishingTools 自动启动

DataStore 配置前会自动检查并启动 PublishingTools 服务，这是 DataStore 注册到 Server 的必要条件。

### 4. Portal WebContextURL 自动更新

Portal 创建后会自动更新 WebContextURL 为实际 IP 地址，并重启 Portal 使配置生效，避免 localhost 问题。

### 5. 异常处理

如果自动化配置失败，脚本会：
- 输出失败原因和浏览器手动处理地址
- 继续完成后续步骤
- 在最终总结中列出需要手动处理的项

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | CentOS 7+, RHEL 7+, Ubuntu 18+ |
| 内存 | ≥ 8GB (生产环境推荐 16GB+) |
| CPU | ≥ 4核 |
| 磁盘 | ≥ 20GB (安装目录) + ≥ 30GB (数据目录) |
| 端口 | 6443, 7443, 2443, 9876, 9877 可用 |
| 权限 | root |

## 安装结果

安装完成后，可通过以下地址访问（使用实际 IP）：

| 服务 | 地址 |
|------|------|
| Server Manager | `https://<IP>:6443/geoscene/manager` |
| Server REST | `https://<IP>:6443/geoscene/rest/services` |
| Portal | `https://<IP>:7443/geoscene/home` |
| Portal Admin | `https://<IP>:7443/geoscene/portaladmin` |
| DataStore | `https://<IP>:2443/geoscene/datastore` |

## 日志文件

- 安装日志: `/var/log/geoscene_YYYYMMDD_HHMMSS.log`
- 状态记录: `/var/log/.geoscene_install_state`

## 常见问题

### Q: 授权文件命名规则？

A: 授权文件匹配规则：
- **Server 授权**: 
  - `.prvc` 文件：任意命名都会被识别为 Server 授权
  - `.ecp` 文件：任意命名都会被识别为 Server/Enterprise 授权
  - 示例：`GeoSceneServerAdvanced_*.prvc`、`authorization_geoscene_*.ecp`
- **Portal 授权**: 
  - `.json` 文件：文件名需包含 `portal` 或 `enterprise` 关键字
  - 示例：`GeoScene_Enterprise_Portal_*.json`、`portal_license.json`

**注意**: 如果同时存在多个 `.prvc` 或 `.ecp` 文件，脚本会选择第一个匹配的文件。建议只保留一个 Server 授权文件。 (如: `*portal*.json`, `*enterprise*.json`)

### Q: 为什么需要使用实际 IP？

A: 使用 `localhost` 会导致：
- Portal 和 Server 之间的通信失败
- DataStore 注册失败
- 跨组件通信问题

脚本自动检测并使用实际 IP 解决这些问题。

### Q: 自动化配置失败怎么办？

A: 脚本会提示浏览器手动处理的地址，例如：
- Server 授权/站点: `https://<IP>:6443/geoscene/manager`
- Portal 门户: `https://<IP>:7443/geoscene/home`
- DataStore 配置: `https://<IP>:2443/geoscene/datastore`

### Q: 如何跳过自动化配置？

A: 使用 `--skip-config` 参数：
```bash
bash install-geoscene.sh --skip-config
```
脚本只会安装软件并启动 Server，后续配置需要手动执行。

### Q: 如何查看帮助信息？

```bash
# 简要帮助
bash install-geoscene.sh --help
bash uninstall-geoscene.sh --help

# 完整手册
bash install-geoscene.sh --man
bash uninstall-geoscene.sh --man
```

### Q: 如何彻底卸载？

```bash
# 安全卸载 (保留数据目录)
bash uninstall-geoscene.sh

# 彻底清理 (删除所有数据)
bash uninstall-geoscene.sh --purge

# 强制彻底清理 (忽略错误)
bash uninstall-geoscene.sh --purge --force
```

### Q: 如何自定义安装目录？

A: 通过配置文件设置：
```bash
# geoscene.conf
GS_HOME=/opt/geoscene
GS_BASE=/opt/geoscene/geoscene
```

### Q: PublishingTools 服务有什么作用？

A: PublishingTools 服务是 DataStore 配置的必要条件。脚本会在 DataStore 配置前自动检查并启动该服务。

## 示例配置文件

```bash
# geoscene.conf - 全自动化配置示例

# 用户和目录
GS_USER=geoscene
GS_GROUP=geoscene
GS_HOME=/home/geoscene
GS_BASE=/home/geoscene/geoscene

# 端口
SERVER_PORT=6443
PORTAL_PORT=7443
DATASTORE_PORT=2443

# Server 管理员
SITE_ADMIN_USER=siteadmin
SITE_ADMIN_PASS=YourPassword123

# Portal 管理员
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
```
