#!/usr/bin/perl

##
# B06 - Temporary items
##

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

use strict;
use CGI;
use C4::Context;
use C4::Output;
use C4::Auth;
use C4::Callnumber::OlimpWS;

=head1

find tle physical adress from OLIMP

=cut

my $input = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {   template_name   => "stack/ajax.tmpl",
            query           => $input,
            type            => "intranet",
            authnotrequired => 0,
            debug => 1,    } );

my $callnumber = $input->param('callnumber');
my ($location, $adress) = FindLocationAndAddress($callnumber);
$template->param( return => $adress  );

output_html_with_http_headers $input, $cookie, $template->output;
1;
