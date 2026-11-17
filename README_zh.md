# luci-app-tvgate

OpenWrt 上的 TVGate LuCI 应用。

[English](README.md)

## 简介

TVGate 是一款高性能的本地网络资源转发与代理工具。它可以将内网资源（如 HTTP、HTTPS、RTSP、RTP）通过 HTTP 转发到外网，外网用户通过访问 Go 程序所在主机的端口（默认 8888）即可访问流媒体或请求代理资源。

## 功能特性

- 自动检测系统架构并下载对应的 TVGate 二进制文件
- 支持通过代理加速 GitHub Release 下载（例如 https://hk.gh-proxy.com/）
- Web UI 管理界面，方便配置和管理
- 实时显示服务状态
- 支持多种架构（x86_64、aarch64、armv7l 等）

## 安装

### 方式一：直接下载安装包（推荐）

安装包由 CI 在推送 tag 时自动构建，发布在 Releases：

<https://github.com/qist/luci-app-tvgate/releases/latest>

| 系统 | 包格式 | 附件 |
|---|---|---|
| OpenWrt 22.03 / 23.05 | opkg（`.ipk`） | `openwrt-22.03.5-luci-app-tvgate_<版本>_all.ipk` |
| OpenWrt 25.12+ | apk-tools（`.apk`） | `openwrt-25.12.0-rc2-luci-app-tvgate-<版本>-r1.apk` |
| 语言包（可选） | 同系统 | `openwrt-*-luci-i18n-tvgate-zh-cn-*`、`openwrt-*-luci-i18n-tvgate-en-*` |
| 校验和 | - | `sha256sums.txt` |

> 包与架构无关（`all` / `noarch`），x86_64 只是构建环境，任意架构路由器都能装。

**opkg（OpenWrt 22.03 / 23.05）**

```bash
cd /tmp
opkg update
opkg install curl ca-certificates unzip luci-compat luci luci-base
opkg install libustream-openssl ca-bundle
opkg install ./openwrt-22.03.5-luci-app-tvgate_*_all.ipk
opkg install ./openwrt-22.03.5-luci-i18n-tvgate-zh-cn_*_all.ipk   # 可选：中文语言包
```

**apk-tools（OpenWrt 25.12+）**

```bash
cd /tmp
apk update
apk add curl ca-certificates unzip luci-compat luci luci-base
apk add --allow-untrusted ./openwrt-25.12.0-rc2-luci-app-tvgate-*.apk
apk add --allow-untrusted ./openwrt-25.12.0-rc2-luci-i18n-tvgate-zh-cn-*.apk   # 可选
```

**校验与卸载**

```bash
sha256sum -c sha256sums.txt          # 校验下载文件（可选）

opkg remove luci-app-tvgate luci-i18n-tvgate-zh-cn   # opkg 卸载
apk del luci-app-tvgate luci-i18n-tvgate-zh-cn       # apk 卸载
```

### 方式二：从源码 / SDK 编译

```bash
# 把本仓库放到 OpenWrt 源码或 SDK 的 package/ 下；
# SDK 不自带 feeds，必须先更新 luci feed 并安装 luci-base（提供 luci.mk 与 po2lmo）
./scripts/feeds update luci
./scripts/feeds install luci-base

# 选中包再编译（不选中时 compile 不会产出任何包）
echo "CONFIG_PACKAGE_luci-app-tvgate=m" >> .config
make defconfig
make package/luci-app-tvgate/compile V=s
```

产物：`bin/packages/<架构>/base/luci-app-tvgate_<版本>_all.ipk`（OpenWrt 25.12+ 为 `.apk`）。

## 配置

安装完成后，可在 LuCI 界面中配置 TVGate：
1. 导航至 服务 -> TVGate
2. 如需加速下载，配置下载代理（例如 https://hk.gh-proxy.com/）
3. 点击「下载/更新二进制」下载 TVGate 可执行文件
4. 启用服务并配置监听端口
5. 保存并应用设置

## 使用方法

服务运行后：
- 访问 Web 管理界面：`http://[路由器IP]:[端口]/[Web路径]`
- 访问 IPTV 流媒体：`http://[路由器IP]:[端口]/[代理URL路径]`

## 技术细节

- 应用自动检测系统架构并下载对应的二进制文件
- 发布包使用 ZIP 格式，下载后自动解压
- 通过 procd 管理服务，支持自动重启
- 配置文件由 TVGate 自动生成

## 支持的架构

- x86_64 (amd64)
- i686/i386/i486/i586 (386)
- aarch64/arm64 (ARM64)
- armv7l/armv7 (ARMv7)
- armv6l/armv6 (ARMv6)
- armv5l/armv5 (ARMv5)
- loongarch64/loong64 (LoongArch)
- mips64el (MIPS64 小端序)
- mips64 (MIPS64)
- mipsel/mipsle (MIPS 小端序)
- mips (MIPS)
- ppc64le (PowerPC 64 小端序)
- ppc64 (PowerPC 64)
- riscv64 (RISC-V 64)
- s390x (IBM System z)
