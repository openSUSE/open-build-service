#
# $Id:$
#
# Makefile to transform a RNC file into a RNG file
# validates the RNG file automatically.
#
# Used tools:
# - trang: Converts the schema
# - jing:  Validates the schema
#

.PHONY: all
all:  kiwi.rng
	@echo "*** Validating KIWI Schema..."
	jing relaxng.rng kiwi.rng

kiwi.rng: kiwi.rnc
	@echo "*** Converting KIWI RNC -> RNG..."
	trang -I rnc -O rng $< $@ 

