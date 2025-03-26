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

resolve_swagger_yaml:
	cd dist/ && LANG=en_US.UTF-8 ./resolve_swagger_yaml.rb -i ../src/api/public/apidocs/OBS-v2.10.50.yaml -o ../src/api/public/apidocs/OBS-v2.10.50.yaml -f
