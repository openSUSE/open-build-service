include ../../../Makefile.include
-include ../../../Makefile.local

all:
	@echo "Targets: test apidocs"

test:
	../restility/bin/rest_test api.txt
	
apidocs:
	sed -i -e 's,#!/usr/bin/ruby.ruby2.5,#!$(OBS_RUBY_BIN),' ../restility/bin/rest_test ../restility/bin/rest_doc
	BUNDLE_GEMFILE=../../../src/api/Gemfile bundle exec ../restility/bin/rest_doc api.txt --html -o ../html

.PHONY: all test apidocs

include ../../../Makefile.targets
