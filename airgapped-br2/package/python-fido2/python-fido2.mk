################################################################################
#
# python-fido2
#
################################################################################

PYTHON_FIDO2_VERSION = 2.0.0
PYTHON_FIDO2_SOURCE = fido2-$(PYTHON_FIDO2_VERSION).tar.gz
PYTHON_FIDO2_SITE = https://files.pythonhosted.org/packages/8d/b9/6ec8d8ec5715efc6ae39e8694bd48d57c189906f0628558f56688d0447b2
PYTHON_FIDO2_SETUP_TYPE = poetry
PYTHON_FIDO2_LICENSE = BSD-2-Clause
PYTHON_FIDO2_LICENSE_FILES = COPYING

$(eval $(python-package))
