all:
	@echo "Targets: test apidocs"

test:
	RUBYLIB=../restility/lib ../restility/bin/rest_test -I .. api.txt
	
apidocs:
	RUBYLIB=../restility/lib ../restility/bin/rest_doc -I .. api.txt --html -o html
