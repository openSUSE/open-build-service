#
# $Id$
#
# Makefile to transform a RNC file into a RNG file
# validates the RNG file automatically.
#
# Used tools:
# - trang: Converts the Schema
# - jing:  Validates the Schema
# - msv:   Another Schema validator
#
.SUFFIXES:
.SUFFIXES: .rng .html .rnc

RNG2XHTML=rng2xhtml.xsl
RELAXNG=relaxng.rng


.PHONY: all
all:  kiwi.rng html

.PHONY: html
html: kiwi.html

.PHONY: test
test: kiwi.rng
	@echo "**** Small Unit Test ****"
	@echo "*** Validating with xmllint..."
	xmllint --noout --relaxng kiwi.rng  /usr/share/kiwi/image/isoboot/*/config.xml
	@echo "*** Validating with msv..."
	msv kiwi.rng /usr/share/kiwi/image/isoboot/*/config.xml
	@echo "*** Finished."

.PHONY: validate val
validate val: .validate
	@echo "*** Validating KIWI Schema..."
	@echo "    --- xmllint validation..."
	xmllint --noout --relaxng $(RELAXNG) kiwi.rng
	@echo "    --- jing validation..."
	jing $(RELAXNG) kiwi.rng
	@echo "    --- msv validation..."
	msv $(RELAXNG) kiwi.rng

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
