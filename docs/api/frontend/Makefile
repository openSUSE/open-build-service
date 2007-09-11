all:
	@echo "Targets: test apidocs"

test:
	RUBYLIB=../restility/lib ../restility/bin/rest_test api.txt
	
apidocs:
	RUBYLIB=../restility/lib ../restility/bin/rest_doc api.txt --html -o ../html
