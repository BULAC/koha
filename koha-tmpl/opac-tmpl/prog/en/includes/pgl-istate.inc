<!-- B011 -->
<!-- TMPL_IF NAME="datedue" -->
    <!-- TMPL_IF NAME="OPACShowCheckoutName" -->
        Checked out to <!-- TMPL_VAR NAME="cardnumber" --> <!-- TMPL_VAR NAME="firstname" --> <!-- TMPL_VAR NAME="surname" -->
    <!-- TMPL_ELSE -->
        Checked out
    <!-- /TMPL_IF -->
<!-- TMPL_ELSIF NAME="transfertwhen" -->
    In transit from <!-- TMPL_VAR NAME="transfertfrom" -->
    to <!-- TMPL_VAR NAME="transfertto" --> since <!-- TMPL_VAR NAME="transfertwhen" -->
<!-- TMPL_ELSIF NAME="waiting" -->
    On hold
<!-- TMPL_ELSIF NAME="wthdrawn" -->
    Item withdrawn
<!-- TMPL_ELSIF NAME="itemlost" -->
    <!-- TMPL_IF NAME="lostimageurl" -->
        <img src="<!-- TMPL_VAR NAME='lostimageurl' -->" alt="<!-- TMPL_VAR NAME='lostimagelabel' -->" title="<!-- TMPL_VAR NAME='lostimagelabel' -->" />
    <!-- TMPL_ELSE -->
        Item lost
    <!-- /TMPL_IF -->
<!-- TMPL_ELSIF NAME="notforloan_per_itemtype" -->
    Not for loan
<!-- TMPL_ELSIF EXPR="!UseStackrequest && itemnotforloan > 0" -->
    Not available
<!-- TMPL_ELSIF NAME="istate" -->
       <!-- TMPL_IF EXPR="istate eq 'NOT_AVAIL'" -->Not available
    <!-- TMPL_ELSIF EXPR="istate eq 'ON_STACK'" -->On stack
    <!-- TMPL_ELSIF EXPR="istate eq 'WAIT_STACK'" -->
        <!-- TMPL_IF NAME="istate_isme" -->
            Wait for delivery
        <!-- TMPL_ELSE -->
            On stack
        <!-- /TMPL_IF -->
    <!-- TMPL_ELSIF EXPR="istate eq 'WAIT_RENEW'" -->
        <!-- TMPL_IF NAME="istate_isme" -->
            Set aside
        <!-- TMPL_ELSE -->
            On stack
        <!-- /TMPL_IF -->
    <!-- TMPL_ELSIF EXPR="istate eq 'RES_GUARD'" -->
        <!-- TMPL_IF NAME="istate_isme" -->
            Set aside
        <!-- TMPL_ELSE -->
            On hold
        <!-- /TMPL_IF -->
    <!-- TMPL_ELSIF EXPR="istate eq 'STACKREQ'" -->
        Requested
    <!-- /TMPL_IF -->
    
    <!-- TMPL_IF NAME="istate_isme" -->
        <!-- TMPL_IF NAME="holdingdesk_ui" -->
            <!-- TMPL_IF EXPR="istate eq 'WAIT_STACK' or istate eq 'WAIT_RENEW' or istate eq 'RES_GUARD'" -->
                at &apos;<!-- TMPL_VAR NAME="holdingdesk_ui" -->&apos;
            <!-- /TMPL_IF -->
        <!-- /TMPL_IF -->
        <!-- TMPL_IF NAME="istate_end_date_ui" -->
            <!-- TMPL_IF EXPR="istate eq 'WAIT_STACK' or istate eq 'WAIT_RENEW' or istate eq 'RES_GUARD'" -->
                untill <!-- TMPL_VAR NAME="istate_end_date_ui" -->
            <!-- /TMPL_IF -->    
        <!-- /TMPL_IF -->
    <!-- /TMPL_IF -->
<!-- TMPL_ELSE -->
    Available
<!-- /TMPL_IF -->