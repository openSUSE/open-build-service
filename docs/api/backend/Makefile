all:
	@echo "Targets: test apidocs"

test:
	../tools/rest_test -I .. api.txt
	
apidocs:
	../tools/rest_doc -I .. api.txt --html -o html
