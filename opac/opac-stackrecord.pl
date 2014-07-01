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
use C4::Biblio;
use C4::Circulation;
use C4::Dates qw/format_date/;
use C4::Members;
use C4::Stack::Search;

use C4::Output;

my $query = new CGI;
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-stackrecord.tmpl",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);

# get borrower information ....
my $borr = GetMemberDetails( $borrowernumber );

$template->param($borr);

my $itemtypes = GetItemTypes();

# get params
my $order  = $query->param('order') || '';
if ( $order eq 'title' ) {
	$order = "title ASC";
    $template->param( orderbytitle => 1 );
}
else {
    $order = "end_date DESC";
    $template->param( orderbydate => 1 );
}

my $limit = $query->param('limit') || '50';
if ( $limit eq 'full' ) {
    $limit = ''; # no limit
}
elsif ($limit !~ /\d/g) {
    $limit = '50'; # protect against hacking
}

my $stacks = GetStacksOfBorrower( $borrowernumber, 1, $order, $limit );

my @bordat;
$bordat[0] = $borr;
$template->param( BORROWER_INFO => \@bordat );

my @loop_stack;

foreach my $stack (@$stacks) {
    my %line;
	
    my $record = GetMarcBiblio($stack->{'biblionumber'});

	# XISBN Stuff
	my $isbn               = GetNormalizedISBN($stack->{'isbn'});
	$line{normalized_isbn} = $isbn;
    $line{biblionumber}    = $stack->{'biblionumber'};
    $line{title}           = $stack->{'title'};
    $line{author}          = $stack->{'author'};
    $line{itemcallnumber}  = $stack->{'itemcallnumber'};
    $line{returndate}      = $stack->{'end_date_ui'};
    $line{volumeddesc}     = $stack->{'volumeddesc'};
    if($stack->{'itemtype'}) {
        $line{'description'}   = $itemtypes->{ $stack->{'itemtype'} }->{'description'};
        $line{imageurl}        = getitemtypeimagelocation( 'opac', $itemtypes->{ $stack->{'itemtype'}  }->{'imageurl'} );
    }
    push( @loop_stack, \%line );
    $line{subtitle} = GetRecordValue('subtitle', $record, GetFrameworkCode($stack->{'biblionumber'}));
}

if (C4::Context->preference('BakerTaylorEnabled')) {
	$template->param(
		JacketImages=>1,
		BakerTaylorEnabled  => 1,
		BakerTaylorImageURL => &image_url(),
		BakerTaylorLinkURL  => &link_url(),
		BakerTaylorBookstoreURL => C4::Context->preference('BakerTaylorBookstoreURL'),
	);
}

BEGIN {
	if (C4::Context->preference('BakerTaylorEnabled')) {
		require C4::External::BakerTaylor;
		import C4::External::BakerTaylor qw(&image_url &link_url);
	}
}

for(qw(AmazonCoverImages GoogleJackets)) {	# BakerTaylorEnabled handled above
	C4::Context->preference($_) or next;
	$template->param($_=>1);
	$template->param(JacketImages=>1);
}

$template->param(
    STACK_RECORD => \@loop_stack,
    limit          => $limit,
    showfulllink   => 1,
	stackrecview => 1,
	count          => scalar @loop_stack,
);

output_html_with_http_headers $query, $cookie, $template->output;
