<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:a="http://relaxng.org/ns/compatibility/annotations/1.0" 
  xmlns:r="http://relaxng.org/ns/structure/1.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:exsl="http://exslt.org/common"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml" 
  exclude-result-prefixes="a r xsi exsl">

<xsl:output method="xml" 
  encoding="UTF-8" 
  indent="yes" 
  doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" 
  doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>



<!--<xsl:key name="div" match="r:div" use="db:refname"/>
<xsl:key name="elems" match="r:element" use="@name"/>-->
<xsl:key name="defs" match="r:define" use="@name"/>
<!--<xsl:key name="pattern" match="r:define" use="@name"/>-->
<xsl:key name="elemdef" match="r:define" use="r:element/@name"/>

<!--  -->
<xsl:param name="html.title">RELAX NG Schema Documentation</xsl:param>
<xsl:param name="html.stylesheet"></xsl:param>
<xsl:param name="html.head">KIWI Schema Documentation</xsl:param>
<xsl:param name="separator"> ::= </xsl:param>
<xsl:param name="schema.name">KIWI</xsl:param>

<xsl:template match="/">
  <html>
    <head>
      <meta name="generator"   content="RNG2XHTML"/>
      <meta name="description" content="RNG to XHTML documentation"/>
      <meta name="schema"      content="{$schema.name}"/>
    </head>
    <title><xsl:value-of select="$html.title"/></title>
    <style type="text/css"><xsl:text>
.define, .start { 
  border-top: 1pt dashed darkgray;
  margin-bottom: 2em;
}

.patterndef { 
  color:black; background-color:lightgray;
  margin-bottom: 2em;
}
    </xsl:text></style>
    <xsl:if test="$html.stylesheet">
      <link rel="stylesheet" href="{$html.stylesheet}" type="text/css"/>  
    </xsl:if>
    <xsl:choose>
      <xsl:when test="r:grammar">
        <xsl:apply-templates mode="synopsis"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">ERROR: Expected grammar element!</xsl:message>
      </xsl:otherwise>
    </xsl:choose>    
  </html>
</xsl:template>


<xsl:template match="*"/>

<!-- ###################################### -->

<xsl:template match="r:grammar" mode="synopsis">
  <body>
    <h1>RELAX NG Schema Documentation for <xsl:value-of select="$schema.name"/></h1>
    <hr/>
    <div class="elementdiv" id="elementstoc">
      <h2>Elements</h2>
      <ul>
      <xsl:apply-templates select="r:div/r:define/r:element" mode="toc">
          <xsl:sort select="@name"/>
        </xsl:apply-templates>
      </ul>
    </div>
    
    <hr/>
    
    <div class="start" id="startpattern">
      <h2>Start Pattern</h2>
      <xsl:apply-templates select="r:start" mode="synopsis"/>
    </div>
    
    <hr/>
    <div class="definediv" id="elementpattern">
      <h2>Element Patterns</h2>
      <xsl:apply-templates select="r:div/r:define[r:element]" mode="synopsis">
        <xsl:sort select="@name"/>
      </xsl:apply-templates>
    </div>    
  </body>
</xsl:template>

<!-- 
  Templates in mode="toc" create a table of contents of all elements
-->

<xsl:template match="r:element" mode="toc">
  <li>
  <p>
    <a>
      <xsl:attribute name="href">
        <xsl:text>#</xsl:text>
        <xsl:value-of select="ancestor::r:define/@name"/>
      </xsl:attribute>      
      <xsl:value-of select="@name"/>
    </a>
    <xsl:if test="a:documentation">
      <xsl:text> &#x2013; </xsl:text>
      <xsl:value-of select="a:documentation"/>  
    </xsl:if>    
  </p>
  </li>
</xsl:template>

<!-- 
   Templates in mode="synopsis" creates the content model
-->
<xsl:template match="r:grammar/r:start" mode="synopsis">
    <code>
      <xsl:text>start</xsl:text>
      <xsl:value-of select="$separator"/>
      <xsl:apply-templates mode="synopsis"/>
    </code>
</xsl:template>
  
<xsl:template match="r:define[r:element]" mode="synopsis">
  <xsl:variable name="title" select="r:element/@name"/>
  
  <div class="define" id="{@name}">
    <h3>Element <xsl:value-of select="$title"/></h3>
    <!-- Doku -->
    <xsl:if test="r:element/a:documentation">
      <p><xsl:value-of select="r:element/a:documentation"/></p>
    </xsl:if>
    <h4>Content Modell</h4>
    <code>
      <xsl:apply-templates mode="synopsis"/>
    </code>
    <h4>Attributes</h4>
    <xsl:apply-templates mode="attributes"/>
  </div>
</xsl:template>


<xsl:template match="r:element" mode="synopsis">
  
  <xsl:message> ==><xsl:value-of 
    select="local-name(..)"/>:  <xsl:value-of 
      select="@name"/> "<xsl:value-of 
      select="ancestor::r:define/@name"/>" <!-- 
  --></xsl:message>
  
  <xsl:value-of select="@name"/>
  <xsl:value-of select="$separator"/>
  
  <xsl:text>( </xsl:text>
  <xsl:apply-templates mode="synopsis"/>
  <xsl:text> )</xsl:text>
  
</xsl:template>

<xsl:template match="a:documentation|text()" mode="synopsis"/>

<xsl:template match="r:text" mode="synopsis">
  <xsl:text>text</xsl:text>
</xsl:template>

<xsl:template match="r:empty" mode="synopsis">
  <xsl:text>empty</xsl:text>
</xsl:template>


<xsl:template match="r:ref" mode="synopsis">
  <xsl:variable name="elemName"
      select="(key('defs', @name)/r:element)[1]/@name"/>
  
  <xsl:message>   ref = <xsl:value-of select="$elemName"/></xsl:message>
  <xsl:if test="$elemName != ''">
      <a href="#{@name}">
        <xsl:value-of select="key('defs',@name)/r:element/@name"/>
        <xsl:apply-templates mode="synopsis"/>
      </a>
      <xsl:if test="following-sibling::r:*">
        <xsl:text> </xsl:text>
      </xsl:if>
  </xsl:if>
</xsl:template>

<xsl:template match="r:oneOrMore" mode="synopsis">
  <xsl:apply-templates mode="synopsis"/>
  <xsl:text>+ </xsl:text>
</xsl:template>

<xsl:template match="r:zeroOrMore" mode="synopsis">
  <xsl:apply-templates mode="synopsis"/>
  <xsl:text>* </xsl:text>
</xsl:template>

<xsl:template match="r:optional" mode="synopsis">
  <xsl:apply-templates mode="synopsis"/>
  <xsl:text>? </xsl:text>
</xsl:template>


<xsl:template match="r:group" mode="synopsis">
  <xsl:choose>
    <xsl:when test="parent::r:element">
      <xsl:apply-templates mode="synopsis"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text> ( </xsl:text>
      <xsl:apply-templates mode="synopsis"/>
      <xsl:text> ) </xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Attributes -->

<xsl:template match="a:documentation" mode="attributes"/>
  


</xsl:stylesheet>
