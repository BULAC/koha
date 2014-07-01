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

=head1 NAME

blinddetail-biblio-search.pl : script to show an authority in MARC format

=head1 SYNOPSIS


=head1 DESCRIPTION

This script needs an authid

It shows the authority in a (nice) MARC format depending on authority MARC
parameters tables.

=head1 FUNCTIONS

=over 2

=cut

use strict;
use warnings;

use C4::AuthoritiesMarc;
use C4::Auth;
use C4::Context;
use C4::Output;
use CGI;
use MARC::Record;
use C4::Koha;

my $query = new CGI;

my $dbh = C4::Context->dbh;

my $authid       = $query->param('authid');
my $index        = $query->param('index');
my $tagid        = $query->param('tagid');
my $authtypecode = &GetAuthTypeCode($authid);

my $auth_type = GetAuthType($authtypecode);
my $record;
if ($authid) {
    $record = GetAuthority($authid);
}

# open template
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "authorities/pgl-sub-authority.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { editcatalogue => 'edit_catalogue' },
    }
);

# Aythority main entry
my $main_entry;
if ($authid) {
	# main entry is always in a subfield
    $main_entry = $record->subfield( $auth_type->{auth_tag_to_report} , 'a');
}
$template->param( "mainentry" => $main_entry );

# Subfield destination
my $dest_subfield;
my $mapping = C4::Context->preference('AuthTypeToSubfieldMapping');
if ($mapping) {
	$mapping =~ s/[^\w=>,]//g; # delete unwanted characters
	foreach my $line (split(/,/, $mapping)) {
		my ($curr_code, $curr_subfield) = split(/=>/, $line);
		if ( $curr_code && $curr_code eq $authtypecode ) {			
	       $dest_subfield = $curr_subfield;
	       last;
		}
	}	
}
$template->param( "destsubfield" => $dest_subfield );

# Other
$template->param(
    authid => $authid ? $authid : "",
    index  => $index,
    tagid  => $tagid,
);

output_html_with_http_headers $query, $cookie, $template->output;

