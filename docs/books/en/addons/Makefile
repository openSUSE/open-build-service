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

RNG2DOCBOOK=rng2docbook.xsl
DBHTML=/usr/share/xml/docbook/stylesheet/nwalsh/current//html/docbook.xsl
RELAXNG=kiwi.rng
RELAXNG_TEST=test.rng
HTMLPARAM=--stringparam refentry.generate.name 0 \
	--stringparam refentry.generate.title 1 \
	--stringparam html.stylesheet kiwi.css 

.PHONY: all
all:  test.rng kiwi.rng kiwi.xsd test.xsd docbook html

.PHONY: html
html-old: kiwi.xhtml

.PHONY: docbook
docbook: kiwi.xml

.PHONY: db-html
html: kiwi.html test.html

.PHONY: lala
lala: kiwi.rng
	@echo "**** Small Unit Test ****"
	@echo "*** Validating with xmllint..."
	xmllint --noout --relaxng kiwi.rng  /usr/share/kiwi/image/isoboot/*/config.xml
	@echo "*** Validating with msv..."
	msv kiwi.rng /usr/share/kiwi/image/isoboot/*/config.xml
	@echo "*** Validating with jing..."
	jing kiwi.rng /usr/share/kiwi/image/isoboot/*/config.xml
	@echo "*** Finished."

.PHONY: bob
bob: test.rng
	@echo "**** Small Unit Test ****"
	@echo "*** Validating with xmllint..."
	xmllint --noout --relaxng test.rng  /usr/share/kiwi/test/*/test-case.xml
	@echo "*** Validating with msv..."
	msv test.rng /usr/share/kiwi/test/*/test-case.xml
	@echo "*** Validating with jing..."
	jing test.rng /usr/share/kiwi/test/*/test-case.xml
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

.PHONY: validate.test val
	@echo "*** Validating KIWI Test Schema..."
	@echo "    ---(1) xmllint validation..."
	xmllint --noout --relaxng $(RELAXNG_TEST) test.rng
	@echo "    ---(2) jing validation..."
	jing $(RELAXNG_TEST) test.rng
	@echo "    ---(3) msv validation..."
	msv $(RELAXNG) test.rng

.validate: kiwi.rng
	@echo "*** Validating KIWI Schema..."
	@touch $@
	jing $(RELAXNG) $<

.validate.test: test.rng
	@echo "*** Validating KIWI Test Schema..."
	@touch $@
	jing $(RELAXNG_TEST) $<

%.rng: %.rnc
	@echo "*** Converting KIWI RNC -> RNG..."
	trang -I rnc -O rng $< $@

%.xsd: %.rnc
	@echo "*** Converting KIWI RNC -> XSD..."
	trang $< $@

%.dtd: %.rnc
	@echo "*** Converting KIWI RNC -> DTD..."
	trang $< $@

%.xml: %.rng $(RNG2DOCBOOK) .validate .validate.test
	@echo "*** Converting KIWI RNG -> DocBook..."
	xsltproc --output $@ $(RNG2DOCBOOK) $<
	@echo "*** Validating $@..."
	xmllint --valid --noout $@

%.html: %.xml
	@echo "*** Converting KIWI DocBook XML -> HTML..."
	xsltproc --output $@ $(HTMLPARAM) $(DBHTML) $<


clean:
	rm -f *.rng
	rm -f *.xsd
	rm -f *.html
	rm -f .validate.test

#
# EOF
#
