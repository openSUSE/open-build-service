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
RNG2DOCBOOK=rng2docbook.xsl
DBHTML=/usr/share/xml/docbook/stylesheet/nwalsh/current//html/docbook.xsl
RELAXNG=relaxng.rng


.PHONY: all
all:  kiwi.rng docbook html

.PHONY: html
html-old: kiwi.html

.PHONY: docbook
docbook: kiwi.xml

.PHONY: db-html
html: kiwi-db.html

.PHONY: test
test: kiwi.rng
	@echo "**** Small Unit Test ****"
	@echo "*** Validating with xmllint..."
	xmllint --noout --relaxng kiwi.rng  /usr/share/kiwi/image/isoboot/*/config.xml
	@echo "*** Validating with msv..."
	msv kiwi.rng /usr/share/kiwi/image/isoboot/*/config.xml
	@echo "*** Validating with jing..."
	jing kiwi.rng /usr/share/kiwi/image/isoboot/*/config.xml
	@echo "*** Finished."

.PHONY: validate val
validate val: .validate
	@echo "*** Validating KIWI Schema..."
	@echo "    ---(1) xmllint validation..."
	xmllint --noout --relaxng $(RELAXNG) kiwi.rng
	@echo "    ---(2) jing validation..."
	jing $(RELAXNG) kiwi.rng
	@echo "    ---(3) msv validation..."
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

%.xml: %.rng $(RNG2DOCBOOK) .validate
	@echo "*** Converting KIWI RNG -> DocBook..."
	xsltproc --output $@ $(RNG2DOCBOOK) $<
	@echo "*** Validating $@..."
	xmllint --valid --noout $@

%-db.html: %.xml
	@echo "*** Converting KIWI DocBook XML -> HTML..."
	xsltproc --output $@ --stringparam html.stylesheet kiwi.css $(DBHTML) $<



#
# EOF
#
