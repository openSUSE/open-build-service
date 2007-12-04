#
#
#

.PHONY: all
all:  kiwi.rng
	@echo "Validating KIWI Schema..."
	jing relaxng.rng kiwi.rng

kiwi.rng: kiwi.rnc
	@echo "Converting KIWI RNC -> RNG..."
	trang -I rnc -O rng $< $@ 

