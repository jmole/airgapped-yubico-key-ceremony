################################################################################
#
# python-yubikey-manager
#
################################################################################

PYTHON_YUBIKEY_MANAGER_VERSION = 5.8.0
PYTHON_YUBIKEY_MANAGER_SOURCE = yubikey_manager-$(PYTHON_YUBIKEY_MANAGER_VERSION).tar.gz
PYTHON_YUBIKEY_MANAGER_SITE = https://files.pythonhosted.org/packages/b3/09/ba3ca95ed3c8adfb7f8288a33048a963dcc5741eb3e819a8451b65e36a59
PYTHON_YUBIKEY_MANAGER_SETUP_TYPE = poetry
PYTHON_YUBIKEY_MANAGER_LICENSE = BSD-2-Clause
PYTHON_YUBIKEY_MANAGER_LICENSE_FILES = COPYING

$(eval $(python-package))
