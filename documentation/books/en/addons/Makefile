#
# $Id$
#
# Makefile to transform a RNC file into a RNG file
# validates the RNG file automatically.
#
# Used tools:
# - trang: Converts the schema
# - jing:  Validates the schema
#

.SUFFIXES: .rng .html .rnc
.PHONY: all
all:  kiwi.rng html

.PHONY: html
html: kiwi.html

.PHONY: validate val
validate val:
	@echo "*** Validating KIWI Schema..."
	jing relaxng.rng kiwi.rng

.rnc.rng:
	@echo "*** Converting KIWI RNC -> RNG..."
	trang -I rnc -O rng $< $@
	@echo "*** Validating KIWI Schema..."
	jing relaxng.rng kiwi.rng

%.html: %.rng rng2xhtml.xsl
	@echo "*** Creating documentation from KIWI RNG..."
	xsltproc --output $@ rng2xhtml.xsl $<


#
# EOF
#
