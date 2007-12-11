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
.SUFFIXES:
.SUFFIXES: .rng .html .rnc

RNG2XHTML=rng2xhtml.xsl
RELAXNG=relaxng.rng


.PHONY: all
all:  kiwi.rng html

.PHONY: html
html: kiwi.html

.PHONY: validate val
validate val: .validate
#	@echo "*** Validating KIWI Schema..."
#	jing $(RELAXNG) kiwi.rng

.validate: kiwi.rng
	@echo "*** Validating KIWI Schema..."
	@touch $@
	jing $(RELAXNG) $<


%.html: %.rng $(RNG2XHTML) .validate
	@echo "*** Creating documentation from KIWI RNG..."
	xsltproc --output $@ $(RNG2XHTML) $<

%.rng: %.rnc
	@echo "*** Converting KIWI RNC -> RNG..."
	trang -I rnc -O rng $< $@
	# @echo "*** Validating KIWI Schema..."
	# jing $(RELAXNG) $@
	
#
# EOF
#
