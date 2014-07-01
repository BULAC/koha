   <!-- TMPL_IF EXPR="state eq 'A'" -->Asked
<!-- TMPL_ELSIF EXPR="state eq 'E'" -->Edited
<!-- TMPL_ELSIF EXPR="state eq 'R'" -->Running
<!-- TMPL_ELSIF EXPR="state eq 'F'" -->Finished
<!-- /TMPL_IF -->
<!-- TMPL_IF NAME="cancel_code" -->(Canceled)<!-- /TMPL_IF -->