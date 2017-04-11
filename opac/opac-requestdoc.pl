#!/usr/bin/perl

# Copyright Katipo Communications 2002
# Copyright Koha Development team 2012
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

use strict;
use warnings;
use CGI qw ( -utf8 );
use C4::Auth;    # checkauth, getborrowernumber.
use C4::Koha;
use C4::Circulation;
use C4::Reserves;
use C4::Biblio;
use C4::Items;
use C4::Output;
use C4::Context;
use C4::Members;
use C4::Overdues;
use C4::Debug;
use C4::Stats;
use Koha::DateUtils;
use Koha::DateUtils;
use DateTime::Duration;
use Date::Calc qw/Today Date_to_Days/;

my $maxreserves = C4::Context->preference("maxreserves");

my $query = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-requestdoc.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);

my $borrower = GetMemberDetails( $borrowernumber );
$template->param( BORROWER_INFO => $borrower );

    # check if this user can place a reserve, -1 means use sys pref, 0 means dont block, 1 means block
    if ( $borrower->{'BlockExpiredPatronOpacActions'} ) {

	if ( $borrower->{'is_expired'} ) {

	    # cannot reserve, their card has expired and the rules set mean this is not allowed
	    $template->param( message => 1, expired_patron => 1 );
	    get_out( $query, $cookie, $template->output );
	}
    }

    # Pass through any reserve charge
    if ($borrower->{reservefee} > 0){
	$template->param( RESERVE_CHARGE => sprintf("%.2f",$borrower->{reservefee}));
    }

    my $branch = $query->param('branch') || $borrower->{'branchcode'} || C4::Context->userenv->{branch} || '' ;

my $op = $query->param('op');
my @errors;

$template->param(op => $op);

my $biblionumber = $query->param('biblionumber');
my $genitemnumber = $query->param('genitemnumber');
my $itemnumber = $query->param('itemnumber');
my $biblio;
my $item;
if ($biblionumber) {
    $biblio = GetBiblio($biblionumber);
    $template->param(
	biblio => $biblio,
	);
}
if ($genitemnumber || $itemnumber) {
    $item = ($genitemnumber) ? GetItem($genitemnumber) : GetItem($itemnumber);
    $item->{'itype'} = 'DOC-TMP-MG';
    foreach my $key (qw(replacementpricedate datelastseen timestamp)) {
	delete($item->{$key});
    }
    $template->param(
	item => $item,
	);
}

if ($op eq 'additem') {
    my $itemnumber;
    my $biblioitemnumber;
    $item->{'enumchron'} = $query->param('numbers');
    $item->{'pubyear'} = $query->param('years');
    $item->{'notforloan'} = 0;
    $biblionumber, $biblioitemnumber, $itemnumber = AddItem($item, $biblionumber);
    my $canitembereserved;
    if ($itemnumber) {
	$canitembereserved = CanItemBeReserved( C4::Context->userenv->{'number'}, $itemnumber );
	if ($canitembereserved eq 'OK') {
	    my $found = 'A';
	    my $rank = 0;
	    my $notes = "Périodique issue d'une notice générique\n Si vous ne le trouvez pas pensez à vérifier l'état des collections,\n les autres notices d'exemplaires et le magasin 21";
	    my $resid = AddReserve(
		$branch,
		C4::Context->userenv->{'number'},
		$biblionumber,
		[$biblionumber],
		$rank,
		output_pref({ dt => dt_from_string, dateformat => 'iso' , dateonly => 1 }),
		'',
		$notes,
		$item->{'title'},
		$itemnumber,
		$found,
		$item->{'itype'}
		);
	    UpdateStats (
		{
		    branch             => $branch,
		    type               => 'periogen',
		    borrowernumber     => C4::Context->userenv->{'number'},
		    associatedborrower => $resid,
		    itemnumber         => $itemnumber,
		    itemtype           => $item->{'itype'},
		    ccode              => $item->{'ccode'},
		}
		);
	} else {
	    push @errors, $canitembereserved;
	}
    }
    else {
	push @errors, 'PROBLEM_CREATING_ITEM';
    }
    $template->param (
	itemnumber => $itemnumber,
	);
}
elsif ($op eq 'addbiblioanditem') {
    my $title = $query->param('title');
    my $author = $query->param('author');
    my $callnumber = $query->param('callnumber');
    my $pubyear = $query->param('pubyear');
    my $volume = $query->param('volume');
    my ($biblionumber, $biblioitemnumber);
    ($biblionumber, $biblioitemnumber) = AddBiblio (
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
	    'itemcallnumber' => $callnumber,
	    'enumchron' => $volume,
	}
	, $biblionumber
	);
    my $biblio = GetBiblio($biblionumber);
    my $item = GetItem($itemnumber);
    my $canitembereserved = CanItemBeReserved( C4::Context->userenv->{'number'}, $itemnumber );
    if ($canitembereserved == 'OK') {
	my $found = 'A';
	my $rank = 0;
	my $notes = "Demande de communication\ndepuis le fichier papier";
	my $resid = AddReserve(
	    $branch,
	    C4::Context->userenv->{'number'},
	    $biblionumber,
	    [$biblionumber],
	    $rank,
	    output_pref({ dt => dt_from_string, dateformat => 'iso' , dateonly => 1 }),
	    '',
	    $notes,
	    $item->{'title'},
	    $itemnumber,
	    $found,
	    $item->{'ccode'}
	    );
	UpdateStats (
	    {
		    branch             => $branch,
		    type               => 'periogen',
		    borrowernumber     => C4::Context->userenv->{'number'},
		    associatedborrower => $resid,
		    itemnumber         => $itemnumber,
		    itemtype           => $item->{'itype'},
		    ccode              => $item->{'ccode'},
		}
	    );
    }
    $template->param (
	biblio => $biblio,
	item => $item,
	itemnumber => $itemnumber,
	op => $op,
	);
}
else {
    my $futureop = $query->param('futureop');
    my $pastop = $query->param('pastop');
    if ($futureop) {
	$template->param(
	    futureop   => $futureop,
	    );
    }
    elsif ($pastop) {
	my $biblio = GetBiblio($biblionumber);
	my $item = GetItem($itemnumber);
	$template->param(
	    biblio => $biblio,
	    item => $item,
	    pastop => $pastop,
	    );
    }
}

if (@errors) {
    $template->param (errors => \@errors);
}

output_html_with_http_headers $query, $cookie, $template->output;
