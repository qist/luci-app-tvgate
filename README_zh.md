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

1. 编译软件包：
   ```bash
   make package/luci-app-tvgate/compile V=s
   ```

2. 安装生成的 ipk 包：
   ```bash
   opkg update
   opkg install curl ca-certificates unzip luci-compat luci luci-base
   opkg install libustream-openssl ca-bundle
   opkg install  luci-app-tvgate_2.1.0_all.ipk
   opkg install luci-i18n-tvgate-zh-cn_git-26.126.27721-5978e59_all.ipk
   ```

3. 卸载软件包：
   ```bash
   opkg remove luci-app-tvgate
   opkg remove luci-i18n-tvgate-zh-cn
   ```

4. OpenWrt 25 安装 apk 包：
   ```bash
   apk update
   apk add curl ca-certificates unzip luci-compat luci luci-base
   apk add --allow-untrusted luci-app-tvgate-2.1.0-r1.apk
   apk add --allow-untrusted luci-i18n-tvgate-zh-cn-26.126.27721~5978e59.apk
   ```

5. OpenWrt 25 卸载软件包：
   ```bash
   apk del luci-app-tvgate
   apk del luci-i18n-tvgate-zh-cn
   ```

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
