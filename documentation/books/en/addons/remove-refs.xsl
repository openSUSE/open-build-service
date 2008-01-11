<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:rng="http://relaxng.org/ns/structure/1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- 
  
  "Simplifies" a RELAX NG Schema by removing all ref elements.
  
  This stylesheet creates a "simpler" version of a RELAX NG Schema.
  It resolves any <ref/> tags with the respective contents.
  Any sibling after start is removed, so in the end there are no
  defines anymore, just everything like a monolithic Schema, nested
  under <start>

-->


<xsl:output method="xml"/>

<xsl:key name="define" match="rng:define" use="@name"/>


<xsl:template match="/">
  <xsl:apply-templates mode="removerefs"/>
</xsl:template>

<xsl:template match="*|text()|@*" mode="removerefs">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="removerefs"/>
		<xsl:apply-templates mode="removerefs"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:ref" mode="removerefs">
  <xsl:variable name="def" select="key('define', @name)"/>
  
  <xsl:apply-templates select="$def" mode="resolvedefs"/>
</xsl:template>

<xsl:template match="rng:define" mode="resolvedefs">
  <xsl:apply-templates mode="removerefs"/>
</xsl:template>


</xsl:stylesheet>
