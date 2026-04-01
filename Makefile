#
# Copyright (C) 2023-2024 qist
#
# This is free software, licensed under the MIT License.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-tvgate
PKG_VERSION:=2.1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=qist <juestnow@gmail.com>
PKG_LICENSE:=MIT

LUCI_TITLE:=LuCI Support for TVGate
LUCI_DESCRIPTION:=LuCI interface for TVGate service management. \
	Provides web interface for TVGate configuration, download management, \
	and YAML update automation with internationalization support.
LUCI_DEPENDS:=+curl +ca-certificates +unzip +luci-base
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)/conffiles
/etc/config/tvgate
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/tvgate-download.sh $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/tvgate-update-yaml.sh $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/init.d/tvgate $(1)/etc/init.d/
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	chmod +x /usr/bin/tvgate-download.sh >/dev/null 2>&1
	chmod +x /usr/bin/tvgate-update-yaml.sh >/dev/null 2>&1
	chmod +x /etc/init.d/tvgate >/dev/null 2>&1
	rm -rf /tmp/luci-indexcache
	rm -rf /tmp/luci-modulecache
fi
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	/etc/init.d/tvgate stop >/dev/null 2>&1
	/etc/init.d/tvgate disable >/dev/null 2>&1
fi
exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	rm -rf /tmp/luci-indexcache
	rm -rf /tmp/luci-modulecache
	rm -f /usr/bin/tvgate-download.sh
	rm -f /usr/bin/tvgate-update-yaml.sh
	rm -f /etc/init.d/tvgate
fi
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
