
<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl"><!-- TMPL_VAR NAME="LibraryName" --></a></h1><!-- Begin Circulation Resident Search Box -->

<script language="JavaScript" type="text/javascript">
    //<![CDATA[
    $(document).ready(function() {
        
        // MAN130
        selLink = $('#header_search_bottom li>a[href*="' + window.location.pathname + '"]').attr('href');
        if (selLink != null) {
            pos = selLink.lastIndexOf('#', selLink.length);
            tabId = selLink.substring(pos, selLink.length);
            
            if (tabId.length > 0) {
                $("#header_search>ul").tabs("select", tabId);
                $(tabId + ">input[text]").focus();
            }
        }
        // END MAN130
        
    });
    //]]>
</script>

<div id="header_search">
    <!-- TMPL_INCLUDE NAME="patron-search-box.inc" -->
<!-- TMPL_IF NAME="CAN_user_circulate" -->
<div id="checkin_search" class="residentsearch" style="display:none;">
    <p class="tip">Scan a barcode to check in:</p>
    <form method="post" action="/cgi-bin/koha/circ/returns.pl">
        <input name="barcode" id="ret_barcode" size="40" accesskey="r" />
        <input value="Submit" class="submit" type="submit" />
    </form>
</div><!-- /TMPL_IF -->

<!-- B032 -->
    <!-- TMPL_IF EXPR="UseStackrequest && CAN_user_circulate" -->
        <!-- TMPL_INCLUDE NAME="stack/retrieval-box.inc" -->
        <!-- TMPL_INCLUDE NAME="stack/delivery-box.inc" -->
        <!-- TMPL_INCLUDE NAME="stack/allop-box.inc" -->
    <!-- /TMPL_IF -->
<!-- END B032 -->

<!-- TMPL_IF NAME="CAN_user_catalogue" -->
<div id="catalog_search" class="residentsearch" style="display:none;">
    <p class="tip">Enter search keywords:</p>
    <form action="/cgi-bin/koha/catalogue/search.pl"  method="get" id="cat-search-block">
        <input type="text" name="q" id="search-form" size="40" accesskey="q" />
        <input type="submit" class="submit" value="Submit"/>
    </form>
</div><!-- /TMPL_IF -->

<ul id="header_search_bottom">
    <!-- TMPL_IF NAME="CAN_user_circulate" --><li><a href="/cgi-bin/koha/circ/circulation.pl#circ_search">Check Out</a></li><!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_circulate" --><li><a href="/cgi-bin/koha/circ/returns.pl#checkin_search">Check In</a></li><!-- /TMPL_IF -->
    <!-- B032 -->
        <!-- TMPL_IF EXPR="UseStackrequest && CAN_user_circulate" -->
            <li><a href="/cgi-bin/koha/stack/stack-retrieval.pl#retrieval_box">Retrieval</a></li>
            <li><a href="/cgi-bin/koha/stack/stack-delivery.pl#delivery_box">Delivery</a></li>
            <li><a href="/cgi-bin/koha/stack/all-operations.pl#allop_box">All operations</a></li>
        <!-- /TMPL_IF -->
    <!-- END B032 -->
    <!-- TMPL_IF NAME="CAN_user_catalogue" --><li><a href="/cgi-bin/koha/catalogue/search.pl#catalog_search">Search the Catalog</a></li><!-- /TMPL_IF -->
</ul>   

</div>

<!-- End Circulation Resident Search Box -->
