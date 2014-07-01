<?xml version="1.0" encoding="UTF-8"?>

<!DOCTYPE stylesheet [<!ENTITY nbsp "&#160;" >]>

<xsl:stylesheet version="1.0"
  xmlns:marc="http://www.loc.gov/MARC21/slim"
  xmlns:items="http://www.koha.org/items"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  exclude-result-prefixes="marc items">

<xsl:import href="UNIMARCslimUtils.xsl"/>
<xsl:output method = "xml" indent="yes" omit-xml-declaration = "yes" />
<xsl:key name="item-by-status" match="items:item" use="items:status"/>
<xsl:key name="item-by-status-and-branch" match="items:item" use="concat(items:status, ' ', items:homebranch)"/>

<xsl:template match="/">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="marc:record">
  <xsl:variable name="leader" select="marc:leader"/>
  <xsl:variable name="leader6" select="substring($leader,7,1)"/>
  <xsl:variable name="leader7" select="substring($leader,8,1)"/>
  <xsl:variable name="biblionumber"
   select="marc:controlfield[@tag=001]"/>
  <xsl:variable name="isbn"
   select="marc:datafield[@tag=010]/marc:subfield[@code='a']"/>
  <!-- PROGILONE - april 2010 - F21 --><xsl:variable name="OPACBranchTooltipDisplay" select="marc:sysprefs/marc:syspref[@name='OPACBranchTooltipDisplay']"/>

  <xsl:if test="marc:datafield[@tag=200]">
    <xsl:for-each select="marc:datafield[@tag=200]">
      <xsl:variable name="title" select="marc:subfield[@code='a']"/>
      <xsl:variable name="ntitle"
       select="translate($title, '&#x0098;&#x009C;','')"/>
      <div>
        <xsl:call-template name="addClassRtl" />
        <span class="results_summary">
          <span class="label"/>
          <a>
            <xsl:attribute name="href">/cgi-bin/koha/opac-detail.pl?biblionumber=<xsl:value-of select="$biblionumber"/></xsl:attribute>
            <xsl:value-of select="$ntitle" />
          </a>
          <xsl:if test="marc:subfield[@code='e']">
            <xsl:text> : </xsl:text>
            <xsl:for-each select="marc:subfield[@code='e']">
              <xsl:value-of select="."/>
            </xsl:for-each>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='b']">
            <xsl:text> [</xsl:text>
            <xsl:value-of select="marc:subfield[@code='b']"/>
            <xsl:text>]</xsl:text>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='f']">
            <xsl:text> / </xsl:text>
            <xsl:value-of select="marc:subfield[@code='f']"/>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='g']">
            <xsl:text> ; </xsl:text>
            <xsl:value-of select="marc:subfield[@code='g']"/>
          </xsl:if>
        </span>
      </div>
    </xsl:for-each>
  </xsl:if>

  <xsl:call-template name="tag_4xx" />

  <xsl:call-template name="tag_210" />

  <xsl:call-template name="tag_215" />

  <span class="results_summary">
    <span class="label">Disponibilité: </span>
    <xsl:choose>
      <xsl:when test="marc:datafield[@tag=856]">
        <xsl:for-each select="marc:datafield[@tag=856]">
          <xsl:choose>
            <xsl:when test="@ind2=0">
              <a>
                <xsl:attribute name="href">
                  <xsl:value-of select="marc:subfield[@code='u']"/>
                </xsl:attribute>
                <xsl:choose>
                  <xsl:when test="marc:subfield[@code='y' or @code='3' or @code='z']">
                    <xsl:call-template name="subfieldSelect">                        
                      <xsl:with-param name="codes">y3z</xsl:with-param>                    
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:when test="not(marc:subfield[@code='y']) and not(marc:subfield[@code='3']) and not(marc:subfield[@code='z'])">
                    Click here to access online
                  </xsl:when>
                </xsl:choose>
              </a>
              <xsl:choose>
                <xsl:when test="position()=last()"></xsl:when>
                <xsl:otherwise> | </xsl:otherwise>
              </xsl:choose>
            </xsl:when> 
          </xsl:choose>
        </xsl:for-each>
      </xsl:when>
      <xsl:when test="count(key('item-by-status', 'available'))=0 and count(key('item-by-status', 'reference'))=0">
        Pas de copie disponible
      </xsl:when>
      <xsl:when test="count(key('item-by-status', 'available'))>0">
        <span class="available">
          <b><xsl:text>Available: </xsl:text></b>
          <xsl:variable name="available_items" select="key('item-by-status', 'available')"/>
          <xsl:for-each select="$available_items[generate-id() = generate-id(key('item-by-status-and-branch', concat(items:status, ' ', items:homebranch))[1])]">
            <!-- PROGILONE - april 2010 - F21 --><span class="branchref" ><xsl:value-of select="items:homebranch"/></span>
  			    <xsl:if test="items:itemcallnumber != '' and items:itemcallnumber">[<xsl:value-of select="items:itemcallnumber"/>]
  			    </xsl:if>
            <xsl:text> (</xsl:text>
            <xsl:value-of select="count(key('item-by-status-and-branch', concat(items:status, ' ', items:homebranch)))"/>
            <xsl:text>)</xsl:text>
            <xsl:choose>
              <xsl:when test="position()=last()">
                <xsl:text>. </xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>, </xsl:text>
              </xsl:otherwise>
            </xsl:choose>
            <!-- PROGILONE - april 2010 - F21 -->
            <xsl:if test="$OPACBranchTooltipDisplay!='0'">
                <span class="branchdetails" >
                    <xsl:if test="items:branchaddress1 != '' and items:branchaddress1">
                        <span class="branchaddress" ><xsl:value-of select="items:branchaddress1"/></span>
                    </xsl:if>
                    <xsl:if test="items:branchaddress2 != '' and items:branchaddress2">
                        <span class="branchaddress" ><xsl:value-of select="items:branchaddress2"/></span>
                    </xsl:if>
                    <xsl:if test="items:branchaddress3 != '' and items:branchaddress3">
                        <span class="branchaddress" ><xsl:value-of select="items:branchaddress3"/></span>
                    </xsl:if>
                    <xsl:if test="(items:branchzip != '' and items:branchzip) or (items:branchcity != '' and items:branchcity)">
                        <span class="branchaddress" ><xsl:value-of select="items:branchzip"/><xsl:text> </xsl:text><xsl:value-of select="items:branchcity"/></span>
                    </xsl:if>
                    <xsl:if test="items:branchcountry != '' and items:branchcountry">
                        <span class="branchaddress" ><xsl:value-of select="items:branchcountry"/></span>
                    </xsl:if>
                    <xsl:if test="items:branchphone != '' and items:branchphone">
                        <span class="branchphone" ><xsl:value-of select="items:branchphone"/></span>
                    </xsl:if>
                    <xsl:if test="items:branchnotes != '' and items:branchnotes">
                        <span class="branchnotes" ><xsl:value-of select="items:branchnotes"/></span>
                    </xsl:if>
                </span>
            </xsl:if>
            <!-- End PROGILONE -->
          </xsl:for-each>
        </span>
      </xsl:when>
    </xsl:choose>
    <!-- MAN340 -->
    <xsl:if test="count(key('item-by-status', 'unavailable'))>0">
      <span class="unavailable">
        <xsl:text>Not available (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'unavailable'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <!-- END MAN340 -->
    <xsl:if test="count(key('item-by-status', 'Withdrawn'))>0">
      <span class="unavailable">
        <xsl:text>Withdrawn (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'Withdrawn'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <xsl:if test="count(key('item-by-status', 'Lost'))>0">
      <span class="unavailable">
        <xsl:text>Lost (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'Lost'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <xsl:if test="count(key('item-by-status', 'Damaged'))>0">
      <span class="unavailable">
        <xsl:text>Damaged (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'Damaged'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <xsl:if test="count(key('item-by-status', 'On Orangemanr'))>0">
      <span class="unavailable">
        <xsl:text>On order (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'On order'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <xsl:if test="count(key('item-by-status', 'In transit'))>0">
      <span class="unavailable">
        <xsl:text>In transit (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'In transit'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <xsl:if test="count(key('item-by-status', 'Waiting'))>0">
      <span class="unavailable">
        <xsl:text>On hold (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'Waiting'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
  </span>

</xsl:template>

</xsl:stylesheet>
