all:
	make -C docs/api/api apidocs

install:
	make -C dist install
	make -C src/api install
	make -C src/backend install

test:
	make -C src/api test
	make -C dist test
	make -C src/backend test

clean:
	make -C src/api clean
