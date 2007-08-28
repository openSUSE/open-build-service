# .PHONY: default
# default: help


ifndef DTDROOT
DTDPATH1 = /usr/share/susedoc
DTDPATH2 = $(shell test -d ../../novdoc && (cd ../../novdoc; pwd))
DTDPATH3 = $(shell test -d ../../../../trunk/novdoc && (cd ../../../../trunk/novdoc; pwd))

DTDROOT := $(firstword $(DTDPATH2) $(DTDPATH3) $(DTDPATH1))
else
include $(DTDROOT)/make/common.mk
endif

.PHONY: dtdroot
dtdroot:
	@echo $(DTDROOT)

# Emacs:
# Local Variables:
# End:
