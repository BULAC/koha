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
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use strict;
use warnings;

use CGI;
use C4::Auth;
use C4::Koha;
use C4::Output;

my $query = new CGI;

my ( $template, $borrowernumber, $cookie ) = &get_template_and_user(
    {
        template_name   => "opac-spaces.tmpl",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
    }
);

my $op = $query->param( 'op' );

if ( $op eq 'booking' ) {
	$template->param(
		'booking' => 'booking',
		'op' => $op
	);
} elsif ( $op eq 'invitation' ) {
	$template->param(
		'invitation' => 'invitation',
		'op' => $op
	);
}

my $session = '';
if ( $cookie =~ /CGISESSID\=([a-zA-z0-9]+)\;/ ) {
	$session = $1;
	$template->param( kohaSessionId => $session );
}

output_html_with_http_headers $query, $cookie, $template->output;
