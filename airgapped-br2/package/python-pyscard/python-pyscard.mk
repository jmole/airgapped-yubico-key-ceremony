################################################################################
#
# python-pyscard
#
################################################################################

PYTHON_PYSCARD_VERSION = 2.3.1
PYTHON_PYSCARD_SOURCE = pyscard-$(PYTHON_PYSCARD_VERSION).tar.gz
PYTHON_PYSCARD_SITE = https://files.pythonhosted.org/packages/93/c9/65c68738a94b44b67b3c5e68a815890bbd225f2ae11ef1ace9b61fa9d5f3
PYTHON_PYSCARD_SETUP_TYPE = setuptools
PYTHON_PYSCARD_LICENSE = LGPL-2.1
PYTHON_PYSCARD_LICENSE_FILES = LICENSE
PYTHON_PYSCARD_DEPENDENCIES = host-swig pcsc-lite
PYTHON_PYSCARD_ENV = SWIG=$(HOST_DIR)/bin/swig

$(eval $(python-package))
