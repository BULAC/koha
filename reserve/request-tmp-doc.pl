#!/usr/bin/perl


#written 2/1/00 by chris@katipo.oc.nz
# Copyright 2000-2002 Katipo Communications
# Parts Copyright 2011 Catalyst IT
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

=head1 request.pl

script to place reserves/requests

=cut

use strict;
use warnings;
use C4::Branch;
use CGI qw ( -utf8 );
use List::MoreUtils qw/uniq/;
use Date::Calc qw/Date_to_Days/;
use C4::Output;
use C4::Auth;
use C4::Reserves;
use C4::Biblio;
use C4::Items;
use C4::Koha;
use C4::Circulation;
use C4::Dates qw/format_date/;
use C4::Utils::DataTables::Members;
use C4::Members;
use C4::Search;		# enabled_staff_search_views
use Koha::DateUtils;

my $dbh = C4::Context->dbh;
my $sth;
my $input = new CGI;
my ( $template, $borrowernumber, $cookie, $flags ) = get_template_and_user(
    {
        template_name   => "reserve/request-tmp-doc.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { reserveforothers => 'place_holds' },
    }
);

my $branch = C4::Context->userenv->{branch};

my $biblionumber   = $input->param('biblionumber');
my $genitemnumber  = $input->param('genitemnumber');
my $cardnumber     = $input->param('cardnumber');
my $title          = $input->param('title') || 'NA';
my $author         = $input->param('author') || 'NA';
my $itemcallnumber = $input->param('itemcallnumber');
my $enumchron      = $input->param('enumchron') || 'NA';
my $pubyear        = $input->param('pubyear') || 'NA';

my $borrower;
if ( $cardnumber ) {
    $borrower = GetMember('cardnumber' => $cardnumber) ;
    $template->param('borrower' => $borrower);
}

if ( $biblionumber && $genitemnumber ) { #need to rerun with borrower number
    $template->param('biblionumber' => $biblionumber);
    $template->param('genitemnumber'   => $genitemnumber);
}
elsif ( $biblionumber && $genitemnumber && $cardnumber && $enumchron) { #make hold
    my $biblio = GetBiblio($biblionumber);
    my $item   = GetItem($genitemnumber);
    $item->{'itype'} = 'DOC-TMP-MG';
    foreach my $key qw(replacementpricedate datelastseen timestamp) {
	delete($item->{$key});
    }
    my ($biblionumber, $biblioitemnumber, $itemnumber) = AddItem($item, $biblionumber);
    my $canitembereserved = CanItemBeReserved( $borrower->{'borrowernumber'}, $itemnumber ) ;
    if ($canitembereserved eq 'OK') {
	my $found = 'A';
	my $rank = 0;
	my $error;
	my $notes = "Périodique issue d'une notice générique\n Si vous ne le trouvez pas pensez à vérifier l'état des collections\n, les autres notices d'exemplaires\net le magasin 21";
	AddReserve(
	    $branch, $borrower->{'borrowernumber'},
	    $biblionumber, 'a', [$biblionumber],
	    $rank, C4::Dates->new()->output(), '',
	    $notes, $item->{'title'},
	    $itemnumber, $found
	    );
    }
    $template->param('biblio' => $biblio);
    $template->param('item' => $item);
}
elsif ( $cardnumber && $itemcallnumber) { #make a card catalog request
	my ($biblionumber, $biblioitemnumber) = AddBiblio (
	    TransformKohaToMarc(
		{
		    'biblio.title' => $title,
		    'biblio.author' => $author,
		    'biblioitems.publicationyear' =>  $pubyear,
		}
	    )
	    , ''
	    );
	my $itemnumber;
	($biblionumber, $biblioitemnumber, $itemnumber) = AddItem(
	    {
		'homebranch' => $branch,
		'holdingbranch' => $branch,
		'notforloan' => 0,
		'itype' => 'DOC-TMP-MG',
		'itemcallnumber' => $itemcallnumber,
		'enumchron' => $enumchron,
	    }
	    , $biblionumber
	    );
	my $canitembereserved = CanItemBeReserved( $borrower->{'borrowernumber'}, $itemnumber ) ;
	open my $dead, '>', '/tmp/dead';
	print $dead "$borrower->{'borrowernumber'}, $canitembereserved\n";
	if ($canitembereserved eq 'OK') {
	    print $dead "WE'RE IN\n";
	    my $found = 'A';
	    my $rank = 0;
	    my $error;
	    my $notes = "Demande de communication\ndepuis le fichier papier";
	    AddReserve(
		$branch, $borrower->{'borrowernumber'},
		$biblionumber, 'a', [$biblionumber],
		$rank, C4::Dates->new()->output(), '',
		$notes, $title,
		$itemnumber, $found
		);
	    $template->param('biblionumber'   => $biblionumber,
			     'itemnumber'     => $itemnumber,
			     'title'          => $title,
			     'author'         => $author,
			     'itemcallnumber' => $itemcallnumber,
		);
	}
	else {
	    $template->param('reserveerror' => $canitembereserved);
	}
}

$template->param('cardnumber' => $cardnumber );

# printout the page
output_html_with_http_headers $input, $cookie, $template->output;

