<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="xml" indent="yes" omit-xml-declaration="no"/>
<xsl:strip-space elements="type"/>

<xsl:template match="*|processing-instruction()|comment()" mode="conv14to20">
  <xsl:copy>
    <xsl:copy-of select="@*"/>
    <xsl:apply-templates mode="conv14to20"/>
  </xsl:copy>  
</xsl:template>
  

<xsl:template match="/">
  <xsl:choose>
    <xsl:when test="image[@schemeversion='1.4']">
      <xsl:apply-templates mode="conv14to20"/>
    </xsl:when>
    <xsl:when test="image[@schemeversion='2.0']">
      <xsl:message terminate="yes">
        <xsl:text>Already at version 2.0... skipped</xsl:text>
      </xsl:message>
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


<para xmlns="http://docbook.org/ns/docbook"> Changed attribute <tag
      class="attribute">schemeversion</tag> from <literal>1.4</literal>
    to <literal>2.0</literal>. 
</para>
<xsl:template match="image" mode="conv14to20">
  <image schemeversion="2.0">
    <xsl:copy-of select="@name"/>
    <xsl:apply-templates mode="conv14to20"/>
  </image>
</xsl:template>


<para xmlns="http://docbook.org/ns/docbook">
  Copy all attributes, when contents is NOT 'split'.
  If contents contains 'split' and attribute <tag class="attribute">filesystem</tag>
  contains a comma, then split this attribute and create
  two new attributes <tag class="attribute"
      >fsreadwrite</tag> and <tag class="attribute">fsreadonly</tag>.
</para>
<xsl:template match="type" mode="conv14to20" >
  <xsl:variable name="fs" select="normalize-space(@filesystem)"/>
  <xsl:variable name="contents" select="."/>
  
  <type>
    <xsl:choose>
      <xsl:when test="$contents != 'split'">
        <xsl:copy-of select="@*"/>
        <xsl:apply-templates mode="conv14to20"/>
      </xsl:when>
      <xsl:when test="$contents = 'split' and contains($fs, ',')">
        <xsl:attribute name="fsreadwrite">
          <xsl:value-of select="substring-before($fs, ',')"/>
        </xsl:attribute>
        <xsl:attribute name="fsreadonly">
          <xsl:value-of select="substring-after($fs, ',')"/>
        </xsl:attribute>
        <xsl:copy-of select="@boot"/>
		<xsl:copy-of select="@format"/>
        <xsl:apply-templates mode="conv14to20"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">
          <xsl:text>ERROR: If element type contains 'split', attribute </xsl:text>
          <xsl:text>filesystem MUST contain the name of the read-write and read-only </xsl:text>
          <xsl:text>filesystem separated by comma.&#10;</xsl:text>
          <xsl:text>SOLUTION: Insert the respective values and </xsl:text>
          <xsl:text>separate them with commas.</xsl:text>
        </xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </type>
</xsl:template>


<para xmlns="http://docbook.org/ns/docbook"> 
  Change attribute value <tag class="attribute">boot</tag> to 
  <tag class="attribute">bootstrap</tag>.
</para>
<xsl:template match="packages[@type='boot']" mode="conv14to20">
  <packages type="bootstrap">
    <xsl:apply-templates mode="conv14to20"/>
  </packages>
</xsl:template>


</xsl:stylesheet>
