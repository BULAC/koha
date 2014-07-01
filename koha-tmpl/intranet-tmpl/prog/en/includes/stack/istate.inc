<!-- B011 -->
<span class="istate">
   <!-- TMPL_IF EXPR="istate eq 'NOT_AVAIL'" -->Not available<!-- TMPL_IF NAME="notforloanvalue" --> (<!-- TMPL_VAR NAME="notforloanvalue" -->)<!-- /TMPL_IF -->
<!-- TMPL_ELSIF EXPR="istate eq 'ON_LOAN'" -->On loan
<!-- TMPL_ELSIF EXPR="istate eq 'ON_STACK'" -->On stack
<!-- TMPL_ELSIF EXPR="istate eq 'WAIT_STACK'" -->Wait for delivery
<!-- TMPL_ELSIF EXPR="istate eq 'WAIT_RENEW'" -->Wait for delivery
<!-- TMPL_ELSIF EXPR="istate eq 'RES_GUARD'" -->Set aside
<!-- TMPL_ELSIF EXPR="istate eq 'STACKREQ'" -->Requested
<!-- TMPL_ELSE -->Available
<!-- /TMPL_IF -->
</span>