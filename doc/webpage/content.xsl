<?xml version="1.0" encoding="utf-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<xsl:template match="@*|node()">
		<xsl:copy>
			<xsl:apply-templates select="@*|node()"/>
		</xsl:copy>
	</xsl:template>

	<xsl:template match="div[@class='toc_block']">
		<div class="toc_block">
			<xsl:apply-templates select="//h2" mode="toc"/>
		</div>
		<div class="clear"></div>
	</xsl:template>

	<xsl:template match="h2" mode="toc">
		<div class="toc_entry">
			<a class="toc">
				<xsl:attribute name="href">
					<xsl:text>#sec</xsl:text>
					<xsl:value-of select="@id"/>
				</xsl:attribute>
				<xsl:value-of select="."/>
			</a>
		</div>
	</xsl:template>

</xsl:stylesheet>
