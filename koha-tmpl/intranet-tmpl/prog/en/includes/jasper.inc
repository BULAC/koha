<div id="jasper_errors"></div>
<div id="jasper_infos"></div>
<div id="jasper_print"></div>

<script type="text/javaScript" language="JavaScript">
//<![CDATA[

        [% IF (report_zipfile) %]
		$(document).ready(function() {
			location = '/cgi-bin/koha/edition/download.pl?directory=[% report_zipdirectory %]&file=[% report_zipfile %]';
		});
	[% END %]

	[% IF (report_errors) %]
		$(document).ready(function() {
			var divInner = '';
			divInner += '<div class="dialog alert"><h3 style="border: 0px; padding: 0px">Error JasperServer</h3><ul>';

			[% FOREACH error IN report_errors %]
				[% IF (item) %]
					divInner += '<li>Error while creating the report <b>[% error.report_name %]</b> for the item <b>[% item %]</b>.</li>';
				[% END %]

				[% IF (serial) %]
					divInner += '<li>Error while creating the report <b>[% error.report_name %]</b> for the serial <b>[% serial %]</b>.</li>';
				[% END %]

				[% IF (borrower) %]
					divInner += '<li>Error while creating the report <b>[% error.report_name %]</b> for the borrower <b>[% borrower %]</b>.</li>';
				[% END %]

				[% IF (stack_request) %]
					divInner += '<li>Error while creating the report <b>[% error.report_name %]</b> for the stack request <b>[% stack_request %]</b>.</li>';
				[% END %]

				[% IF (no_report_param) %]
					divInner += '<li>Error while creating the report <b>[% error.report_name %]</b>.</li>';
				[% END %]
			[% END %]

			divInner += '</ul></div>';

			document.getElementById('jasper_errors').innerHTML = divInner;
		});
	[% END %]

	[% IF (report_infos) %]
		$(document).ready(function() {
			var divInner = '';
			divInner += '<div class="dialog alert"><h3 style="border: 0px; padding: 0px">Message JasperServer</h3><ul>';
			[% FOREACH report IN report_infos %]
				[% IF (quitus) %]
					var message1 = _("The quitus can not be printed for the borrower because of the following : ");
					var message2 = _("the borrower has ");
					var message3 = _(" issue(s)");
					var message4 = _(" stack request(s)");
					var message5 = _("the borrower has outstanding fines of");
					divInner += '<li>' + message1 + '<ul><div style="margin-left: auto;margin-right: auto;width: 350px;text-align: left;">';
					[% IF (nb_issues) %]
						divInner += '<li>' + message2 + '<b>[% nb_issues %]</b>' + message3 + '</li>';
					[% END %]
					[% IF (nb_stacks) %]
						divInner += '<li>' + message2 + '<b>[% nb_stacks %]</b>' + message4 + '</li>';
					[% END %]
					[% IF (total_fines) %]
						divInner += '<li>' + message5 + '<b>[% total_fines %]</b></li>';
					[% END %]
					divInner += '</ul></div></li>';
				[% END %]
			[% END %]

			divInner += '</ul></div>';

			document.getElementById('jasper_infos').innerHTML = divInner;
		});
	[% END %]

	[% IF (report_print) %]
		$(document).ready(function() {
			var divInner = '';
			divInner += '<div class="dialog alert"><h3 style="border: 0px; padding: 0px">Message JasperServer</h3><ul>';
			divInner += '<li>The report has been sent to the printer.</li>';
			divInner += '</ul></div>';

			document.getElementById('jasper_print').innerHTML = divInner;
		});
	[% END %]

//]]>
</script>
