<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:a="http://relaxng.org/ns/compatibility/annotations/1.0"
  xmlns:rng="http://relaxng.org/ns/structure/1.0"
  xmlns:db="http://docbook.org/ns/docbook"
  xmlns:exsl="http://exslt.org/common"
  exclude-result-prefixes="db a rng exsl">

<!--
  http://www.techquila.com/download/LICENSE.txt
Copyright (c) 2004 Khalil Ahmed. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. The end-user documentation included with the redistribution, if any, must include the following acknowledgment:

    "This product includes software developed by Kal Ahmed (http://www.techquila.com/)."

Alternately, this acknowledgment may appear in the software itself, if and wherever such third-party acknowledgments normally appear.

THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE APACHE SOFTWARE FOUNDATION OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

- - - - - - - - - - - - - - - - - - - - - 

The stylesheet was modified by Thomas Schraitle:
- Output a DocBook refentry
- Include parameter with-source and with-content-model
- Import additional stylesheet remove-refs.xsl
- Used keys where appropriate
-->

  <xsl:import href="remove-refs.xsl"/>

  <xsl:output indent="yes" method="xml"
    doctype-public="-//OASIS//DTD DocBook XML V4.5//EN"
    doctype-system="http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd"/>
  
 <xsl:strip-space elements="*"/>


  <xsl:key name="define" match="rng:define" use="@name"/>
  <xsl:key name="elemdef" match="rng:define" use="rng:element/@name"/>

  <!-- 
  The main title for the generated documentation. 
-->
  <xsl:param name="title">RELAX-NG KIWI Schema Documentation</xsl:param>

  <!-- 
  The text to provide as a default string for elements, patterns or 
  attributes with no documentation strings.
-->
  <xsl:param name="default.documentation.string"
    select="'No documentation available.'"/>

 
  <!-- 
  If specified, limits the documentation generated to just the named 
  element or define. If there are multiple matches (i.e. you have used 
  the same name for both an element and a pattern) then documentation
  will be generated for all matches.
-->
  <xsl:param name="target"/>
  
  <!-- 
    If specified, a refsect1 with the content modell is generated
    1=yes, 0=no
  -->
  <xsl:param name="with-content-model" select="1"/>
  
  <!-- 
    If specified, include the source code of the respective element
    1=yes, 0=no
  -->
  <xsl:param name="with-source" select="0"/>

  <!-- 
    Parameter for content modell separation
  -->
  <xsl:param name="CMseparator"> ::= </xsl:param>

  
  <xsl:variable name="simplified.tree.rtf">
     <xsl:apply-templates mode="removerefs"/>
  </xsl:variable>
  
  <xsl:variable name="simplified.tree" select="exsl:node-set($simplified.tree.rtf)/*"/>
 
 <xsl:template match="/">
   <xsl:apply-templates/>
 </xsl:template>
   
  <xsl:template match="rng:grammar">        
    <reference>
      <referenceinfo>
        <pubdate>Published: <xsl:processing-instruction name="dbtimestamp"/></pubdate>
        <xsl:if test="db:info/db:releaseinfo">
          <xsl:for-each select="db:info/db:releaseinfo">
            <releaseinfo><xsl:apply-templates select="."/></releaseinfo>   
          </xsl:for-each>           
        </xsl:if>
        <legalnotice>
          <title>Legal Notice</title>
          <para>This product includes software developed by Khalil Ahmed
              (<ulink url="http://www.techquila.com"/>).</para>
        </legalnotice>
        <authorgroup>
          <author>
            <contrib>Wrote original XSD Schema</contrib>
            <firstname>Marcus</firstname>
            <surname>Schäfer</surname>
            <email>ms (AT) suse.de</email>
          </author>
          <othercredit>
            <contrib>Original Stylesheet</contrib>
            <firstname>Khalil</firstname>
            <surname>Ahmed</surname>
          </othercredit>
          <othercredit>
            <contrib>Rewrote XSD into RNC</contrib>
            <contrib>Modified XSLT stylesheet to output DocBook refentry</contrib>
            <firstname>Thomas</firstname>
            <surname>Schraitle</surname>
            <email>thomas.schraitle (AT) suse.de</email>
          </othercredit>
        </authorgroup>
      </referenceinfo>
      <title><xsl:value-of select="$title"/></title>
        <xsl:choose>
          <xsl:when test="$target">
            <xsl:apply-templates
              select="//rng:element[@name=$target or rng:name=$target]"/>
            <xsl:apply-templates select="//rng:define[@name=$target]"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="//rng:element">
              <xsl:sort select="@name|rng:name" order="ascending"/>
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
    </reference>
  </xsl:template>

  <xsl:template match="rng:element">
    <xsl:variable name="name" select="@name|rng:name"/>
    <xsl:variable name="nsuri">
      <xsl:choose>
        <xsl:when test="ancestor::rng:div[@ns]">
          <xsl:value-of select="ancestor::rng:div[@ns][1]/@ns"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="ancestor::rng:grammar[@ns][1]/@ns"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="nsprefix">
      <xsl:if test="$nsuri">
        <xsl:value-of select="name(namespace::*[.=$nsuri])"/>
      </xsl:if>
    </xsl:variable>
    <xsl:variable name="qname">
      <xsl:choose>
        <xsl:when test="not($nsprefix='')">
          <xsl:value-of select="$nsprefix"/>:<xsl:value-of
            select="$name"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$name"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="parentdefname" select="parent::rng:define/@name"/>
    <xsl:variable name="def.element"
      select="$simplified.tree//rng:define[@name=$parentdefname]/rng:element"/>
    <xsl:variable name="rtf">
      <xsl:apply-templates select="$def.element//rng:attribute" mode="check">
        <xsl:with-param name="name" select="$name"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:variable name="newattrs" select="exsl:node-set($rtf)/*"/>
    
    <!--<xsl:message>rng:element "<xsl:value-of select="$name"/>"
      count($newattrs):    <xsl:value-of select="count($newattrs)"/>
                           <xsl:text>: </xsl:text>
                           <xsl:for-each select="$newattrs">
                             <xsl:value-of select="concat(@name, ' ')"/>
                           </xsl:for-each>
    </xsl:message>-->

    <refentry id="def.{@name}">
      <refnamediv>
        <refname><sgmltag><xsl:value-of select="$qname"/></sgmltag></refname>
        <refpurpose>
          <xsl:choose>
            <xsl:when test="a:documentation">
              <xsl:apply-templates select="a:documentation"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:message>
                <xsl:text>WARNING: No RNG doc string found for element</xsl:text>
                <xsl:value-of select='concat(" &apos;", $qname, "&apos;.")'/>
              </xsl:message>
              <xsl:value-of select="$default.documentation.string"/>
            </xsl:otherwise>
          </xsl:choose>
        </refpurpose>
      </refnamediv>
      <xsl:if test="$with-content-model != 0">
        <refsynopsisdiv role="contentmodel">
          <title>Content Model</title>
          <screen>
              <xsl:value-of select="@name"/>
              <xsl:value-of select="$CMseparator"/>
              <xsl:apply-templates mode="content-model"/>
            </screen>
        </refsynopsisdiv>
      </xsl:if>
      <xsl:if test="db:para">
        <refsect1>
          <title>Description</title>
          <para><xsl:value-of select="db:para"/></para>
        </refsect1>
      </xsl:if>
      
      <refsect1 role="attributes">
          <title>Attributes</title>
          <xsl:choose>
            <xsl:when test="count($newattrs) > 0">
              <informaltable>
                <tgroup cols="3">
                  <thead>
                    <row>
                      <entry>Attribute</entry>
                      <entry>Type</entry>
                      <entry>Use</entry>
                      <entry>Documentation</entry>
                    </row>
                  </thead>              
                  <tbody>
                    <xsl:apply-templates select="$newattrs" mode="attributes"/>
                  </tbody>
                </tgroup>
              </informaltable>
            </xsl:when>
            <xsl:otherwise>
              <para>No attributes available.</para>
            </xsl:otherwise>
          </xsl:choose>          
        </refsect1>
        
        <xsl:if test="$with-source != 0">
          <refsect1>
            <title>Source</title>
            <programlisting><xsl:text 
              disable-output-escaping="yes">&lt;![CDATA[</xsl:text><xsl:copy-of 
              select="."/><xsl:text
                disable-output-escaping="yes">]]&gt;</xsl:text></programlisting>
          </refsect1>
        </xsl:if>
    </refentry>    
  </xsl:template>


  <xsl:template match="rng:attribute" mode="check">
    <xsl:param name="name"/>
    <xsl:variable name="ancest" select="ancestor::rng:element[1]"/>
    
    <xsl:choose>
      <xsl:when test="$ancest[@name=$name]">
        <xsl:copy-of select="."/>
      </xsl:when>
      <xsl:otherwise/><!-- Do nothing -->
    </xsl:choose>
    
  </xsl:template>

  <xsl:template match="rng:attribute" mode="attributes">
    <xsl:param name="matched"/>
    <xsl:param name="optional"/>
    <row>
      <entry>
        <xsl:value-of select="@name"/>
      </entry>
      <entry>
        <xsl:choose>
          <xsl:when test="rng:data"> 
            <type>xsd:<xsl:value-of select="rng:data/@type"/></type>            
          </xsl:when>
          <xsl:when test="rng:text"> TEXT </xsl:when>
          <xsl:when test="rng:choice"> Enumeration:<xsl:text> </xsl:text>
            <xsl:for-each select="rng:choice/rng:value"> 
              <xsl:text>"</xsl:text>
              <sgmltag class="attvalue"><xsl:value-of select="."/></sgmltag>
              <xsl:text>"</xsl:text>
              <xsl:if test="following-sibling::*"> 
                <xsl:text> | </xsl:text>
              </xsl:if>
            </xsl:for-each>
          </xsl:when>
          <xsl:otherwise> TEXT </xsl:otherwise>
        </xsl:choose>
      </entry>
      <entry>
        <xsl:choose>
          <xsl:when test="ancestor::rng:optional">Optional</xsl:when>
          <xsl:when test="boolean($optional)">Optional</xsl:when>
          <xsl:otherwise>Required</xsl:otherwise>
        </xsl:choose>
      </entry>
      <entry>
        <xsl:apply-templates select="a:documentation"/>
      </entry>
    </row>
  </xsl:template>

  <xsl:template match="rng:ref" mode="attributes">
    <xsl:param name="matched"/>
    <xsl:param name="optional"/>
    <xsl:variable name="name" select="@name"/>
    <xsl:variable name="opt" select="count(ancestor::rng:optional) > 0"/>
    <xsl:apply-templates select="key('define', @name)"
      mode="attributes"><!-- //rng:define[@name=$name] -->
      <xsl:with-param name="matched" select="$matched"/>
      <xsl:with-param name="optional"
        select="boolean($optional) or boolean($opt)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="rng:define" mode="attributes">
    <xsl:param name="matched"/>
    <xsl:param name="optional"/>
    <xsl:if test="not(count(matched)=count(matched|.))">
      <xsl:apply-templates
        select=".//rng:attribute[not(ancestor::rng:element)] | 
                .//rng:ref[not(ancestor::rng:element)]"
        mode="attributes">
        <xsl:with-param name="matched" select="$matched|."/>
        <xsl:with-param name="optional"
          select="$optional or ancestor::rng:optional"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>


<!-- 

-->

  <xsl:template match="rng:define">
    <xsl:variable name="name" select="@name"/>
    
    <sect2>
      <title><xsl:value-of select="$name"/></title>
      <xsl:choose>
        <xsl:when
          test="following::rng:define[@name=$name and not(@combine)]">
          <xsl:apply-templates
            select="//rng:define[@name=$name and not(@combine)]"
            mode="define-base"/>
        </xsl:when>
        <xsl:when test="not(preceding::rng:define[@name=$name])">
          <xsl:apply-templates select="." mode="define-base"/>
        </xsl:when>
      </xsl:choose>
    </sect2>    
  </xsl:template>


  <xsl:template match="rng:define" mode="define-base">
    <xsl:variable name="name" select="@name"/>
    <xsl:variable name="hasatts">
      <xsl:apply-templates select="." mode="has-attributes"/>
    </xsl:variable>
    <xsl:variable name="combined">
      <xsl:if test="@combine">
        <xsl:value-of select="following::rng:define[@name=$name]"/>
      </xsl:if>
      <xsl:if test="not(@combine)">
        <xsl:value-of select="//rng:define[@name=$name and @combine]"/>
      </xsl:if>
    </xsl:variable>
    <xsl:variable name="nsuri">
      <xsl:choose>
        <xsl:when test="ancestor::rng:div[@ns][1]">
          <xsl:value-of select="ancestor::rng:div[@ns][1]/@ns"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="ancestor::rng:grammar[@ns][1]/@ns"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="xdefs" select="key('elemdef', rng:element/@name)"/>
    
    <refentry id="{@name}">
      <refnamediv>
          <refname><xsl:value-of select="@name"/></refname>
          <refpurpose>
            <xsl:choose>
              <xsl:when test="a:documentation">
                <xsl:apply-templates select="a:documentation"/>    
              </xsl:when>
              <xsl:otherwise>
                <xsl:message>WARNING: WARNING: No RNG doc string found
                  for define '<xsl:value-of 
                  select="$name"/>'.</xsl:message>
              </xsl:otherwise>
            </xsl:choose>
            
            
          </refpurpose>
      </refnamediv>
      <xsl:if test="$nsuri != ''">
        <refsynopsisdiv>
          <title>Namespaces</title>
          <para><xsl:value-of select="$nsuri"/></para>
        </refsynopsisdiv>
      </xsl:if>
      <xsl:if test="$xdefs">
        <refsynopsisdiv>
          <title>Content Model</title>
          <para>
            <xsl:apply-templates select="*" mode="content-model"/>
            <xsl:if test="@combine">
              <xsl:apply-templates
                select="following::rng:define[@name=$name]"
                mode="define-combine"/>
            </xsl:if>
            <xsl:if test="not(@combine)">
              <xsl:apply-templates
                select="//rng:define[@name=$name and @combine]"
                mode="define-combine"/>
            </xsl:if>
          </para>
        </refsynopsisdiv>
      </xsl:if>
     
      <refsect1>
        <title>Attributes</title>
        <xsl:choose>
          <xsl:when test="starts-with($hasatts, 'true')">
            <informaltable>
              <tgroup cols="3">
                <thead>
                  <row>
                    <entry role="header">
                      <para>Attribute</para>
                    </entry>
                    <entry role="header">
                      <para>Type</para>
                    </entry>
                    <entry role="header">
                      <para>Use</para>
                    </entry>
                    <entry role="header">
                      <para>Documentation</para>
                    </entry>
                  </row>
                </thead>
                <tbody>
                  <xsl:variable name="nesting"
                    select="count(ancestor::rng:element)"/>
                  <xsl:apply-templates
                    select=".//rng:attribute[count(ancestor::rng:element)=$nesting] | .//rng:ref[count(ancestor::rng:element)=$nesting]"
                    mode="attributes">
                    <xsl:with-param name="matched" select="."/>
                  </xsl:apply-templates>
                </tbody>
              </tgroup>
            </informaltable>
          </xsl:when>
          <xsl:otherwise>
            <para>No attributes available.</para>
          </xsl:otherwise>
        </xsl:choose>
      </refsect1>
    </refentry>
  </xsl:template>

  <xsl:template match="rng:define" mode="define-combine">
    <xsl:choose>
      <xsl:when test="@combine='choice'">
       <xsl:text> | (</xsl:text>
       <xsl:apply-templates mode="content-model"/>
       <xsl:text>)</xsl:text>
      </xsl:when>
      <xsl:when test="@combine='interleave'">
        <xsl:text> &amp; (</xsl:text>
        <xsl:apply-templates mode="content-model"/>
        <xsl:text>)</xsl:text>
      </xsl:when>
    </xsl:choose>
  </xsl:template>


  <!-- ================================================= -->
  <!-- CONTENT MODEL PATTERNS                            -->
  <!-- The following patterns construct a text           -->
  <!-- description of an element content model           -->
  <!-- ================================================= -->
  <xsl:template match="rng:element" mode="content-model">
    <link linkend="def.{@name}">
      <xsl:value-of select="@name"/>
    </link>
    <xsl:choose>
      <xsl:when test="parent::rng:interleave and
        following-sibling::rng:*">
        <xsl:text> &amp;&#10;  </xsl:text>
      </xsl:when>
      <xsl:when
          test="not(parent::rng:choice) and 
            (following-sibling::rng:element 
            | following-sibling::rng:optional 
            | following-sibling::rng:oneOrMore 
            | following-sibling::rng:zeroOrMore)">
          <xsl:text>,&#10;  </xsl:text>
        </xsl:when>
      </xsl:choose>
  </xsl:template>

  <xsl:template match="rng:group" mode="content-model">
    <xsl:text>(</xsl:text>
    <xsl:apply-templates mode="content-model"/>
    <xsl:text>)</xsl:text> 
  </xsl:template>

  <xsl:template match="rng:optional" mode="content-model">
    <xsl:if test=".//rng:element | .//rng:ref[not(ancestor::rng:attribute)]">
      <xsl:apply-templates mode="content-model"/>
      <xsl:text>?</xsl:text>
      <xsl:choose>
        <xsl:when test="parent::rng:interleave and
        following-sibling::rng:*">
          <xsl:text> &amp;&#10;  </xsl:text>
        </xsl:when>
        <xsl:when
          test="not(parent::rng:choice) and 
            (following-sibling::rng:element 
            | following-sibling::rng:optional 
            | following-sibling::rng:oneOrMore 
            | following-sibling::rng:zeroOrMore)">
          <xsl:text>,&#10;  </xsl:text>
        </xsl:when>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

  <xsl:template match="rng:oneOrMore" mode="content-model">
    <xsl:text>(</xsl:text>
    <xsl:apply-templates mode="content-model"/>
    <xsl:text>)+</xsl:text>
    <xsl:choose>
      <xsl:when test="parent::rng:interleave and
        following-sibling::rng:*">
        <xsl:text> &amp;&#10;  </xsl:text>
      </xsl:when>
      <xsl:when test="not(parent::rng:choice) and 
            (following-sibling::rng:element 
            | following-sibling::rng:optional 
            | following-sibling::rng:oneOrMore 
            | following-sibling::rng:zeroOrMore
            | following-sibling::rng:ref)">
        <xsl:text>,&#10;  </xsl:text>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="rng:zeroOrMore" mode="content-model">
    <xsl:text>(</xsl:text>
    <xsl:apply-templates mode="content-model"/>
    <xsl:text>)*</xsl:text>
    <xsl:choose>
      <xsl:when test="parent::rng:interleave and
        following-sibling::rng:*">
        <xsl:text> &amp;&#10;  </xsl:text>
      </xsl:when>
      <xsl:when test="not(parent::rng:choice) and 
            (following-sibling::rng:element 
            | following-sibling::rng:optional 
            | following-sibling::rng:oneOrMore 
            | following-sibling::rng:zeroOrMore
            | following-sibling::rng:ref)">
        <xsl:text>,&#10;  </xsl:text>
      </xsl:when>
    </xsl:choose>    
  </xsl:template>

  <xsl:template match="rng:choice" mode="content-model">
    <xsl:text> (</xsl:text>
    <xsl:for-each select="*">
      <xsl:apply-templates select="." mode="content-model"/>
      <xsl:if test="following-sibling::rng:*">
        <xsl:text> | </xsl:text>
      </xsl:if>
    </xsl:for-each>
    <xsl:text>) </xsl:text>
  </xsl:template>

  <xsl:template match="rng:value" mode="content-model"> 
    <xsl:text> "</xsl:text>
    <xsl:value-of select="."/>  
    <xsl:text>" </xsl:text>
  </xsl:template>

  <xsl:template match="rng:empty" mode="content-model">
    <xsl:text> EMPTY</xsl:text>
  </xsl:template>

  <xsl:template match="rng:ref" mode="content-model">
    <xsl:variable name="elemName"
      select="(key('define', @name)/rng:element)[1]/@name"/>
        
    <xsl:if test="$elemName">
      <link linkend="def.{$elemName}"><xsl:value-of select="$elemName"/></link>
      <xsl:choose>
        <xsl:when
          test="parent::rng:interleave and
                following-sibling::rng:*">
          <xsl:text> &amp;&#10;  </xsl:text>
        </xsl:when>
        <xsl:when
          test="not(parent::rng:choice) and 
            (following-sibling::rng:element 
            | following-sibling::rng:optional 
            | following-sibling::rng:oneOrMore 
            | following-sibling::rng:zeroOrMore
            | following-sibling::rng:ref)">
          <xsl:text>,&#10;  </xsl:text>
        </xsl:when>
      </xsl:choose>    
    </xsl:if>
  </xsl:template>

  <xsl:template match="rng:text" mode="content-model"> 
    <xsl:text> TEXT </xsl:text>
    <!--<xsl:if
      test="not(parent::rng:choice) and 
            (following-sibling::rng:element 
            | following-sibling::rng:optional 
            | following-sibling::rng:oneOrMore 
            | following-sibling::rng:zeroOrMore)">
      <xsl:text>,&#10;  </xsl:text>
    </xsl:if>-->
    <xsl:choose>
      <xsl:when test="parent::rng:interleave and
        following-sibling::rng:*">
        <xsl:text> &amp;&#10;  </xsl:text>
      </xsl:when>
      <xsl:when test="not(parent::rng:choice) and 
            (following-sibling::rng:element 
            | following-sibling::rng:optional 
            | following-sibling::rng:oneOrMore 
            | following-sibling::rng:zeroOrMore
            | following-sibling::rng:ref)">
        <xsl:text>,&#10;  </xsl:text>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="rng:data" mode="content-model">
    <xsl:text> xsd:</xsl:text>
    <xsl:value-of select="@type"/>
  </xsl:template>

  <xsl:template match="rng:interleave" mode="content-model">
    <xsl:apply-templates mode="content-model"/>
  </xsl:template>

  <xsl:template match="*" mode="content-model">
    <!-- suppress -->
  </xsl:template>


<!-- Documentation -->
  <xsl:template mode="a:documentation">
    <para>
      <xsl:apply-templates/>
    </para>    
  </xsl:template>

</xsl:stylesheet>
