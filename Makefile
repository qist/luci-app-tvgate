include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-tvgate
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=<yourname> <your@email.com>

LUCI_TITLE:=LuCI Support for TVGate
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+curl +ca-certificates +unzip

define Package/$(PKG_NAME)/conffiles
/etc/config/tvgate
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/tvgate-download.sh $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/tvgate-config-update.sh $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/init.d/tvgate $(1)/etc/init.d/
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	chmod +x /usr/bin/tvgate-download.sh >/dev/null 2>&1
	chmod +x /usr/bin/tvgate-config-update.sh >/dev/null 2>&1
	chmod +x /etc/init.d/tvgate >/dev/null 2>&1
	rm -rf /tmp/luci-indexcache
	rm -rf /tmp/luci-modulecache
fi
exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	rm -rf /tmp/luci-indexcache
	rm -rf /tmp/luci-modulecache
fi
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature