apidocs:
	cd api; make apidocs

doc: apidocs
	xsltproc xs3p.xsl package.xsd >package.html
	xsltproc xs3p.xsl project.xsd >project.html
	xsltproc xs3p.xsl platform.xsd >platform.html
	xsltproc xs3p.xsl projectresult.xsd >projectresult.html
	xsltproc xs3p.xsl packageresult.xsd >packageresult.html
	xsltproc xs3p.xsl status.xsd >status.html

validate:
	python validate_xml.py api/
	python validate_xml.py backend/
