<div id="jasper_errors"></div>
<div id="jasper_infos"></div>
<div id="jasper_print"></div>

<script type="text/javaScript" language="JavaScript">
//<![CDATA[

    <!-- TMPL_IF NAME="report_zipfile" -->
		$(document).ready(function() {
			location = '/cgi-bin/koha/edition/download.pl?directory=<!-- TMPL_VAR NAME="report_zipdirectory" -->&file=<!-- TMPL_VAR NAME="report_zipfile" -->';
		});
	<!-- /TMPL_IF -->

	<!-- TMPL_IF NAME="report_errors" -->
		$(document).ready(function() {
			var divInner = '';
			divInner += '<div class="dialog alert"><h3 style="border: 0px; padding: 0px">Error JasperServer</h3><ul>';

			<!-- TMPL_LOOP NAME="report_errors" -->
				<!-- TMPL_IF NAME="item" -->
					divInner += '<li>Error while creating the report <b><!-- TMPL_VAR NAME="report_name" --></b> for the item <b><!-- TMPL_VAR NAME="item" --></b>.</li>';
				<!-- /TMPL_IF -->

				<!-- TMPL_IF NAME="serial" -->
					divInner += '<li>Error while creating the report <b><!-- TMPL_VAR NAME="report_name" --></b> for the serial <b><!-- TMPL_VAR NAME="serial" --></b>.</li>';
				<!-- /TMPL_IF -->

				<!-- TMPL_IF NAME="borrower" -->
					divInner += '<li>Error while creating the report <b><!-- TMPL_VAR NAME="report_name" --></b> for the borrower <b><!-- TMPL_VAR NAME="borrower" --></b>.</li>';
				<!-- /TMPL_IF -->

				<!-- TMPL_IF NAME="stack_request" -->
					divInner += '<li>Error while creating the report <b><!-- TMPL_VAR NAME="report_name" --></b> for the stack request <b><!-- TMPL_VAR NAME="stack_request" --></b>.</li>';
				<!-- /TMPL_IF -->

				<!-- TMPL_IF NAME="no_report_param" -->
					divInner += '<li>Error while creating the report <b><!-- TMPL_VAR NAME="report_name" --></b>.</li>';
				<!-- /TMPL_IF -->
			<!-- /TMPL_LOOP -->

			divInner += '</ul></div>';

			document.getElementById('jasper_errors').innerHTML = divInner;
		});
	<!-- /TMPL_IF -->

	<!-- TMPL_IF NAME="report_infos" -->
		$(document).ready(function() {
			var divInner = '';
			divInner += '<div class="dialog alert"><h3 style="border: 0px; padding: 0px">Message JasperServer</h3><ul>';
			<!-- TMPL_LOOP NAME="report_infos" -->
				<!-- TMPL_IF NAME="quitus" -->
					var message1 = _("The quitus can not be printed for the borrower because of the following : ");
					var message2 = _("the borrower has ");
					var message3 = _(" issue(s)");
					var message4 = _(" stack request(s)");
					var message5 = _("the borrower has outstanding fines of"); 
					divInner += '<li>' + message1 + '<ul><div style="margin-left: auto;margin-right: auto;width: 350px;text-align: left;">';
					<!-- TMPL_IF NAME="nb_issues" -->
						divInner += '<li>' + message2 + '<b><!-- TMPL_VAR NAME="nb_issues" --></b>' + message3 + '</li>';
					<!-- /TMPL_IF -->
					<!-- TMPL_IF NAME="nb_stacks" -->
						divInner += '<li>' + message2 + '<b><!-- TMPL_VAR NAME="nb_stacks" --></b>' + message4 + '</li>';
					<!-- /TMPL_IF -->
					<!-- TMPL_IF NAME="total_fines" -->
						divInner += '<li>' + message5 + '<b><!-- TMPL_VAR NAME="total_fines" --></b></li>';
					<!-- /TMPL_IF -->
					divInner += '</ul></div></li>';
				<!-- /TMPL_IF -->
			<!-- /TMPL_LOOP -->
	
			divInner += '</ul></div>';
	
			document.getElementById('jasper_infos').innerHTML = divInner;
		});
	<!-- /TMPL_IF -->

	<!-- TMPL_IF NAME="report_print" -->
		$(document).ready(function() {
			var divInner = '';
			divInner += '<div class="dialog alert"><h3 style="border: 0px; padding: 0px">Message JasperServer</h3><ul>';
			divInner += '<li>The report has been sent to the printer.</li>';
			divInner += '</ul></div>';
	
			document.getElementById('jasper_print').innerHTML = divInner;
		});
	<!-- /TMPL_IF -->
	
//]]>
</script>
