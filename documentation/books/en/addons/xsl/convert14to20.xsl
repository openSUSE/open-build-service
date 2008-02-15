<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="xml" indent="yes"/>


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
  When content of element <tag>type</tag> is <literal>split</literal>,
  then insert two new attributes and remove attribute
  <tag class="attribute">filesystem</tag>.
</para>
<xsl:template match="type" mode="conv14to20" >
  <type>
    <xsl:choose>
      <xsl:when test="normalize-space(.) = 'split'">
        <xsl:attribute name="filesystemRW">squashfs</xsl:attribute>
        <xsl:attribute name="filesystemRO">
          <xsl:value-of select="@filesystem"/>
        </xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="@*"/>
      </xsl:otherwise>      
    </xsl:choose>
    <xsl:apply-templates mode="conv14to20"/>
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
