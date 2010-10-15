<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="xml" indent="yes" omit-xml-declaration="no"/>
<xsl:strip-space elements="type"/>

<xsl:template match="*|processing-instruction()|comment()"
  mode="conv20to21">
  <xsl:copy>
    <xsl:copy-of select="@*"/>
    <xsl:apply-templates mode="conv20to21"/>
  </xsl:copy>  
</xsl:template>
  

<xsl:template match="/">
  <xsl:choose>
    <xsl:when test="image[@schemeversion='1.4']">
      <xsl:message terminate="yes">
        <xsl:text>ERROR: Wrong schema version. </xsl:text>
        <xsl:text>Got 1.4, but expected 2.0.</xsl:text>
      </xsl:message>
    </xsl:when>
    <xsl:when test="image[@schemeversion='2.1']">
      <xsl:message terminate="yes">
        <xsl:text>Already at version 2.1... skipped</xsl:text>
      </xsl:message>
    </xsl:when>
    <xsl:when test="image[@schemeversion='2.0']">
      <xsl:apply-templates mode="conv20to21"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:message terminate="yes">
        <xsl:text>ERROR: The Schema version is not correct.&#10;</xsl:text>
        <xsl:text>       I got '</xsl:text>
        <xsl:value-of select="image/@schemeversion"/>
        <xsl:text>', but expected version 1.4.</xsl:text>
      </xsl:message>
    </xsl:otherwise>
  </xsl:choose>  
</xsl:template>

<!-- Insert here you changes: -->

</xsl:stylesheet>
