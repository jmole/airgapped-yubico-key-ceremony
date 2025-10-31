################################################################################
#
# yubico-piv-tool
#
################################################################################

YUBICO_PIV_TOOL_VERSION = 2.7.2
YUBICO_PIV_TOOL_SOURCE = yubico-piv-tool-$(YUBICO_PIV_TOOL_VERSION).tar.gz
YUBICO_PIV_TOOL_SITE = https://developers.yubico.com/yubico-piv-tool/Releases
YUBICO_PIV_TOOL_LICENSE = BSD-2-Clause
YUBICO_PIV_TOOL_LICENSE_FILES = COPYING
YUBICO_PIV_TOOL_DEPENDENCIES = host-pkgconf host-gengetopt openssl pcsc-lite check
YUBICO_PIV_TOOL_INSTALL_STAGING = YES

YUBICO_PIV_TOOL_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release \
	-DBACKEND=pcsc \
	-DBUILD_STATIC_LIB=OFF \
	-DGENERATE_MAN_PAGES=OFF \
	-DBUILD_TESTING=OFF \
	-DENABLE_HARDWARE_TESTS=OFF \
	-DOPENSSL_STATIC_LINK=OFF

$(eval $(cmake-package))
