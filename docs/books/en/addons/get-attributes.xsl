<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  exclude-result-prefixes="db a rng exsl"
  xmlns:exsl="http://exslt.org/common"
  xmlns:a="http://relaxng.org/ns/compatibility/annotations/1.0" 
  xmlns:db="http://docbook.org/ns/docbook" 
  xmlns:rng="http://relaxng.org/ns/structure/1.0"
  xmlns="http://relaxng.org/ns/structure/1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="xml" indent="yes"/>

<xsl:strip-space elements="*"/>

<xsl:key name="define" match="rng:define" use="@name"/>

<xsl:template match="text()">  
</xsl:template>

<xsl:template match="/">
  <grammar xmlns:a="http://relaxng.org/ns/compatibility/annotations/1.0">
    <xsl:apply-templates/>
  </grammar>
</xsl:template>

<xsl:template match="rng:element">
    <xsl:variable name="refs"
      select="rng:ref
            |rng:optional/rng:ref
            |rng:choice/rng:ref
            |rng:group/rng:ref
            |rng:interleave/rng:ref"/>
    <xsl:variable name="attrs"
      select="rng:attribute
            |rng:optional/rng:attribute
            |rng:choice/rng:attribute
            |rng:group/rng:attribute
            |rng:interleave/rng:attribute"/>

    <element name="{@name}">
      <xsl:apply-templates select="$refs|$attrs" mode="ref"/>
    </element>
    <xsl:apply-templates 
      select="rng:element
              |rng:choice/rng:element
              |rng:optional/rng:element
              |rng:interleave/rng:element
              |rng:grammar/rng:start/rng:element
              |rng:group/rng:element
              |rng:list/rng:element
              |rng:oneOrMore/rng:element
              |rng:zeroOrMore/rng:element"/>
</xsl:template>


<xsl:template match="rng:ref" mode="ref">
  <xsl:param name="name" select="@name"/>
  <xsl:variable name="def" select="key('define', @name)[not(rng:element)]"/>
  
  <xsl:apply-templates select="$def" mode="ref">
      <xsl:with-param name="name" select="$name"/>
      <xsl:with-param name="condition"
        select="parent::rng:optional
               |parent::rng:group
               |parent::rng:choice
               |parent::rng:list
               |parent::rng:interleave"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="rng:define" mode="ref">
  <xsl:param name="name" select="@name"/>
  <xsl:param name="condition"/>
  <xsl:variable name="refs-and-attrs" 
    select=".//rng:attribute[not(ancestor::rng:element)]
            |.//rng:ref"/>
  
  <xsl:if test="$refs-and-attrs">
    <xsl:apply-templates select="$refs-and-attrs" mode="ref">
      <xsl:with-param name="name" select="$name"/>
      <xsl:with-param name="condition" select="$condition"/>
    </xsl:apply-templates>
  </xsl:if>
</xsl:template>

<xsl:template match="rng:attribute" mode="ref">
  <xsl:param name="name"/>
  <xsl:param name="condition"/>
  
    <attribute name="{@name}">
      <xsl:choose>
        <xsl:when test="$condition">
          <xsl:attribute name="condition">
            <xsl:value-of select="local-name($condition)"/>
          </xsl:attribute>
        </xsl:when>
        <xsl:when test="parent::rng:optional
                        |parent::rng:choice
                        |parent::rng:group
                        |parent::rng:list
                        |parent::rng:interleave">
          <xsl:attribute name="condition">
            <xsl:value-of select="local-name(parent::rng:*)"/>
          </xsl:attribute>
        </xsl:when>
      </xsl:choose>
      <xsl:if test="$name">
        <xsl:comment> from <xsl:value-of select="$name"/> </xsl:comment>        
      </xsl:if>
      <xsl:choose>
        <xsl:when test="count(rng:*) > 0">
          <xsl:copy-of select="a:documentation|rng:*"/>
        </xsl:when>
        <xsl:otherwise>
          <text/>
        </xsl:otherwise>
      </xsl:choose>      
    </attribute>
</xsl:template>

</xsl:stylesheet>
