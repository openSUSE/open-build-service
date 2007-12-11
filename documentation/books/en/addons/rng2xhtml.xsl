<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:a="http://relaxng.org/ns/compatibility/annotations/1.0" 
  xmlns:r="http://relaxng.org/ns/structure/1.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml" 
  exclude-result-prefixes="a r xsi">

<xsl:output method="xml" 
  encoding="UTF-8" 
  indent="yes" 
  doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" 
  doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>


<xsl:param name="html.title">RELAX NG Schema Documentation</xsl:param>
<xsl:param name="html.stylesheet"></xsl:param>
<xsl:param name="html.head">KIWI Schema Documentation</xsl:param>

<xsl:template match="/">
  <html>
    <head></head>
    <title><xsl:value-of select="$html.title"/></title>
    <meta name="generator" content="RNG2XHTML"/>
    <meta name="description" content="RNG to XHTML documentation"/>
    <style type="text/css"></style>
    <xsl:if test="$html.stylesheet">
      <link rel="stylesheet" href="{$html.stylesheet}" type="text/css"/>  
    </xsl:if>
    <xsl:choose>
      <xsl:when test="r:grammar">
        <xsl:apply-templates/>    
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">ERROR: Expected grammar element!</xsl:message>
      </xsl:otherwise>
    </xsl:choose>    
  </html>
</xsl:template>


<!-- Default templates -->
<xsl:template match="*">
  
</xsl:template>

<!--  -->
<xsl:template match="r:grammar">
  <body>
    <h1><xsl:value-of select="$html.title"/></h1>
    <xsl:apply-templates/>
  </body>
</xsl:template>

</xsl:stylesheet>
