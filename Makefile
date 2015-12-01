all:
	make -C docs/api/api apidocs

install:
	make -C dist install
	make -C src/api install
	make -C src/backend install
