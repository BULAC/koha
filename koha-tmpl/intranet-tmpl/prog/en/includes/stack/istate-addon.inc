<!-- B011 -->
<span class="istate">
<!-- TMPL_IF NAME="notforloan_per_itemtype" -->
    Not for loan
<!-- TMPL_ELSIF EXPR="!UseStackrequest && itemnotforloan > 0" -->
    Not available<!-- TMPL_IF NAME="notforloanvalue" --> (<!-- TMPL_VAR NAME="notforloanvalue" -->)<!-- /TMPL_IF -->
<!-- TMPL_ELSIF EXPR="istate eq 'NOT_AVAIL'" -->
    Not available<!-- TMPL_IF NAME="notforloanvalue" --> (<!-- TMPL_VAR NAME="notforloanvalue" -->)<!-- /TMPL_IF -->
<!-- TMPL_ELSIF EXPR="istate eq 'ON_LOAN'" -->
<!-- TMPL_ELSIF EXPR="istate eq 'ON_STACK'" -->On stack
<!-- TMPL_ELSIF EXPR="istate eq 'WAIT_STACK'" -->Wait for delivery
<!-- TMPL_ELSIF EXPR="istate eq 'WAIT_RENEW'" -->Wait for delivery
<!-- TMPL_ELSIF EXPR="istate eq 'RES_GUARD'" -->Set aside
<!-- TMPL_ELSIF EXPR="istate eq 'STACKREQ'" -->Requested
<!-- TMPL_ELSE -->Available (<!-- TMPL_VAR NAME="notforloanvalue" -->)
<!-- /TMPL_IF -->
<!-- TMPL_IF NAME="istate_borrowernumber" -->
    <!-- TMPL_IF EXPR="istate eq 'ON_STACK'" -->
        by <a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=<!-- TMPL_VAR NAME='istate_borrowernumber' -->">
            <!-- TMPL_IF NAME='hidepatronname' -->
              <!-- TMPL_VAR NAME="istate_cardnumber" -->
            <!-- TMPL_ELSE -->
              <!-- TMPL_VAR NAME="istate_firstname" --> <!-- TMPL_VAR NAME="istate_surname" -->
            <!-- /TMPL_IF -->
        </a>
    <!-- /TMPL_IF -->
<!-- /TMPL_IF -->
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
</span>