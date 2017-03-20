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
use C4::Utils::DataTables::Members;
use C4::Members;
use C4::Search;		# enabled_staff_search_views
use C4::Stats;
use Koha::DateUtils;
use DateTime::Duration;
use Koha::Libraries;

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
my $enumchron      = $input->param('enumchron');
my $pubyear        = $input->param('pubyear');

my $borrower;
if ( $cardnumber ) {
    $borrower = GetMember('cardnumber' => $cardnumber) ;
    $template->param('borrower' => $borrower);
}

if ( $biblionumber && $genitemnumber && ! $cardnumber ) { #need to rerun with borrower number
    my $biblio = GetBiblio($biblionumber);
    my $item   = GetItem($genitemnumber);
    $template->param('biblio' => $biblio,
		     'item'   => $item,
		     'genitemnumber' => $genitemnumber,
		     'biblionumber'  => $biblionumber,
		     'enumchron'     => $enumchron,
		    );

}
elsif ( $biblionumber && $genitemnumber && $cardnumber && $enumchron) { #make hold for periodic request
    my $biblio = GetBiblio($biblionumber);
    my $item   = GetItem($genitemnumber);
    $item->{'itype'} = 'DOC-TMP-MG';
    foreach my $key (qw(replacementpricedate datelastseen timestamp)) {
	delete($item->{$key});
    }
    my $genenumchron = $item->{'enumchron'};
    $item->{'enumchron'} = $enumchron;
    my ($biblionumber, $biblioitemnumber, $itemnumber) = AddItem($item, $biblionumber);
    my $canitembereserved = CanItemBeReserved( $borrower->{'borrowernumber'}, $itemnumber ) ;
    if ($canitembereserved eq 'OK') {
	my $found = 'A';
	my $rank = 0;
	my $error;
	my $notes = "Périodique issue d'une notice générique\n Si vous ne le trouvez pas pensez à vérifier l'état des collections\n, les autres notices d'exemplaires\net le magasin 21";
	my $resid = AddReserve(
	    $branch,
	    $borrower->{'borrowernumber'},
	    $biblionumber,
	    [$biblionumber],
	    $rank,
	    output_pref({ dt => dt_from_string, dateformat => 'iso' , dateonly => 1 }),
	    '',
	    $notes,
	    $item->{'title'},
	    $itemnumber,
	    $found,
	    $item->{'itype'},
	    );
	UpdateStats (
		{
		    branch             => $branch,
		    type               => 'periogen',
		    borrowernumber     => $borrower->{'borrowernumber'},
		    associatedborrower => $resid,
		    itemnumber         => $itemnumber,
		    itemtype           => $item->{'itype'},
		    ccode              => $item->{'ccode'},
		}
	    );
    }
    $template->param('biblio' => $biblio,
		     'item'   => $item,
		     'genitemnumber' => $genitemnumber,
		     'biblionumber'  => $biblionumber,
		     'enumchron'     => $enumchron,
		     'genenumchron'  => $genenumchron,
		     'done'          => 'done',
		    );
}
elsif ( $biblionumber && $genitemnumber && $cardnumber ) { #prepare form for periodic request
    my $biblio = GetBiblio($biblionumber);
    my $item   = GetItem($genitemnumber);
    $template->param('biblio'        => $biblio,
		     'item'          => $item,
		     'biblionumber'  => $biblionumber,
		     'genitemnumber' => $genitemnumber,
		     'cardnumber'    => $cardnumber,
	);
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
	if ($canitembereserved eq 'OK') {
	    my $found = 'A';
	    my $rank = 0;
	    my $error;
	    my $notes = "Demande de communication\ndepuis le fichier papier";
	    my $resid = AddReserve(
		$branch,
		$borrower->{'borrowernumber'},
		$biblionumber,
		[$biblionumber],
		$rank,
		output_pref({ dt => dt_from_string, dateformat => 'iso' , dateonly => 1 }),
		'',
		$notes,
		$title,
		$itemnumber,
		$found,
		'DOC-TMP-MG',
		);
	    UpdateStats (
		{
		branch             => $branch,
		type               => 'cardcatalog',
		borrowernumber     => $borrower->{'borrowernumber'},
		associatedborrower => $resid,
		itemnumber         => $itemnumber,
		itemtype           => 'DOC-TMP-MG',
		ccode              => '',
	    }
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
