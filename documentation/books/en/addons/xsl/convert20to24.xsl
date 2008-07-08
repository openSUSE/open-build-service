<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="xml" indent="yes" omit-xml-declaration="no"/>
<xsl:strip-space elements="type"/>

<xsl:template match="*|processing-instruction()|comment()" mode="conv20to24">
  <xsl:copy>
    <xsl:copy-of select="@*"/>
    <xsl:apply-templates mode="conv20to24"/>
  </xsl:copy>  
</xsl:template>
  

<xsl:template match="/">
  <xsl:choose>
    <xsl:when test="image[@schemeversion='2.0']">
      <xsl:apply-templates mode="conv20to24"/>
    </xsl:when>
    <xsl:when test="image[@schemeversion='2.4']">
      <xsl:message terminate="yes">
        <xsl:text>Already at version 2.4... skipped</xsl:text>
      </xsl:message>
    </xsl:when>
    <xsl:otherwise>
      <xsl:message terminate="yes">
        <xsl:text>ERROR: The Schema version is not correct.&#10;</xsl:text>
        <xsl:text>       I got '</xsl:text>
        <xsl:value-of select="image/@schemeversion"/>
        <xsl:text>', but expected version 2.0.</xsl:text>
      </xsl:message>
    </xsl:otherwise>
  </xsl:choose>  
</xsl:template>


<para xmlns="http://docbook.org/ns/docbook"> Changed attribute <tag
      class="attribute">schemeversion</tag> from <literal>2.0</literal>
    to <literal>2.4</literal>. 
</para>
<xsl:template match="image" mode="conv20to24">
  <image schemeversion="2.4">
     <xsl:choose>
        <xsl:when test="@name">
           <xsl:copy-of select="@name"/>
        </xsl:when>
        <xsl:otherwise>
           <xsl:attribute name="name">FIXME</xsl:attribute>
        </xsl:otherwise>
     </xsl:choose>
    <xsl:apply-templates mode="conv20to24"/>
  </image>
</xsl:template>


<!-- TODO remove attributes memory disk HWversion 
  guestOS_32Bit guestOS_64Bit from all packages sections -->

<xsl:template match="packages" mode="conv20to24">
   <packages>
     <xsl:if test="@memory or 
                   @disk or 
                   @HWversion or 
                   @guestOS_32Bit or 
                   @guestOS_64Bit">
       <xsl:message>
         <xsl:text>INFO: Please use for the attributes memory, disk</xsl:text>
         <xsl:text> HWversion, guestOS_32Bit or guestOS_64Bit&#10;</xsl:text>
         <xsl:text>the new elements vmwareconfig or xenconfig.</xsl:text>
       </xsl:message>
     </xsl:if>
     <xsl:copy-of select="@*[not(local-name(.) = 'memory' or
                             local-name(.) = 'disk' or
                             local-name(.) = 'HWversion' or
                             local-name(.) = 'guestOS_32Bit' or
                             local-name(.) = 'guestOS_64Bit')
                             ]"/>
     <xsl:apply-templates mode="conv20to24"/>
   </packages>
</xsl:template>


<xsl:template match="version" mode="conv20to24">
   <xsl:variable name="text" select="normalize-space(.)"/>
   
   <xsl:choose>
      <xsl:when test=""></xsl:when>
      <xsl:otherwise></xsl:otherwise>
   </xsl:choose>
   
   
</xsl:template>

</xsl:stylesheet>
