<!-- PROGILONE - april 2010 - F10 F11 -->
<div class="detailtagcell" >
    <h2>
    <!-- TMPL_UNLESS NAME="currentsearchisoneresult" -->
        <p><a class="searchwithcontext" href="<!-- TMPL_VAR NAME="currentsearchurl" -->" >Back to results</a></p>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="currentsearchisadvanced" -->
        <p><a href="/cgi-bin/koha/opac-search.pl" >Back to search</a></p>
        <p><a href="/cgi-bin/koha/opac-search.pl?do=Clear">New search</a></p>    
    <!-- TMPL_ELSE -->
        <p><a href="/cgi-bin/koha/opac-main.pl?<!-- TMPL_VAR NAME="currentsearchquery" -->" >Back to search</a></p>
        <p><a href="/cgi-bin/koha/opac-main.pl">New search</a></p>
    <!-- /TMPL_IF -->
    </h2>
</div>
<!-- End PROGILONE -->
