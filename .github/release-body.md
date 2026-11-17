## 安装

安装包在本页 Assets 中，按系统选择：

| 系统 | 包格式 | 文件 |
|---|---|---|
| OpenWrt 22.03 / 23.05 | opkg（`.ipk`） | `openwrt-22.03.5-luci-app-tvgate_*_all.ipk` |
| OpenWrt 25.12+ | apk-tools（`.apk`） | `openwrt-25.12.0-rc2-luci-app-tvgate-*.apk` |
| 语言包（可选） | 同系统 | `openwrt-*-luci-i18n-tvgate-zh-cn-*`、`openwrt-*-luci-i18n-tvgate-en-*` |
| 校验和 | - | `sha256sums.txt` |

> 包与架构无关（`all` / `noarch`），任意架构路由器都能安装。

### opkg（OpenWrt 22.03 / 23.05）

```bash
cd /tmp
opkg update
opkg install curl ca-certificates unzip luci-compat luci luci-base
opkg install libustream-openssl ca-bundle
opkg install ./openwrt-22.03.5-luci-app-tvgate_*_all.ipk
opkg install ./openwrt-22.03.5-luci-i18n-tvgate-zh-cn_*_all.ipk   # 可选：中文语言包
```

### apk-tools（OpenWrt 25.12+）

```bash
cd /tmp
apk update
apk add curl ca-certificates unzip luci-compat luci luci-base
apk add --allow-untrusted ./openwrt-25.12.0-rc2-luci-app-tvgate-*.apk
apk add --allow-untrusted ./openwrt-25.12.0-rc2-luci-i18n-tvgate-zh-cn-*.apk   # 可选
```

### 校验与卸载

```bash
sha256sum -c sha256sums.txt          # 校验下载文件（可选）

opkg remove luci-app-tvgate luci-i18n-tvgate-zh-cn   # opkg 卸载
apk del luci-app-tvgate luci-i18n-tvgate-zh-cn       # apk 卸载
```

安装完成后，在 LuCI「服务 → TVGate」配置并下载/更新 TVGate 二进制。

## 支持的架构

本包为 `all` / `noarch`，不限架构；TVGate 二进制由应用按路由器架构自动下载：

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
