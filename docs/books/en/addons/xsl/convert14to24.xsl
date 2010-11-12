<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
   xmlns:exslt="http://exslt.org/common"
   exclude-result-prefixes="exslt"
   >

<xsl:import href="convert14to20.xsl"/>
<xsl:import href="convert20to24.xsl"/>

<xsl:template match="/">
   <xsl:variable name="node14">
      <xsl:apply-templates select="/" mode="conv14to20"/>
   </xsl:variable>
   
   <xsl:apply-templates select="exslt:node-set($node14)" mode="conv20to24"/>
</xsl:template>

</xsl:stylesheet>
