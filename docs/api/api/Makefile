all:
	@echo "Targets: test apidocs"

test:
	../restility/bin/rest_test api.txt

apidocs:
	BUNDLE_GEMFILE=../../../src/api/Gemfile bundle.ruby2.7 exec ../restility/bin/rest_doc api.txt --html -o ../html
