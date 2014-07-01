#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

#
# PROGILONE - july 2010 - C2
#

use strict;
#use warnings; FIXME - Bug 2505
use C4::Auth;
use CGI;
use C4::Context;

use C4::Search;
use C4::Output;

=head1 NAME

plugin pgl_authority

=head1 SYNOPSIS

This plug-in deals with unimarc subfields 606$9 and 607$9

=head1

plugin_parameters : other parameters added when the plugin is called by the dopop function

=cut
sub plugin_parameters {
    my ($dbh,$record,$tagslib,$i,$tabloop) = @_;
    return "";
}

=head1

plugin_javascript : javascript function

=cut
sub plugin_javascript {
	my ($dbh,$record,$tagslib,$field_number,$tabloop) = @_;
	my $function_name = $field_number;
	
	# prefixe indicating the same subfield
	# ie id=tag_606_subfield_9_245063_11277953359 => prefix = tag_606_subfield_9
	my $field_number_prefixe = substr($field_number, 0, 18); 

	my $res  = "
	<script>
	function Focus$function_name(index) {
		return 1;
	}
	
	function Blur$function_name(subfield_managed) {
		return 1;
	}
	
	function Clic$function_name(subfield_managed) {
		var goto = '../authorities/auth_finder.pl?index=' + subfield_managed + '&editauthtypecode=1';
		// get subfield clones
		var subfields = \$('#' + subfield_managed).parent().parent().find(\"input[id^='$field_number_prefixe']\");
		if (subfields.length > 0) {
			if (subfield_managed != subfields[0].id) {
				// not first subfield so use sub-authority behavior
			  	goto += '&onchoose=pgl-sub-authority';
            }
			window.open(goto,'_blank','width=700,height=500,toolbar=false,scrollbars=yes');
		}
	}
	</script>
	";
	
	return ($function_name,$res);
}

=head1

plugin : template construction

=cut
sub plugin {
    #  not used
}

1;
