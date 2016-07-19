#!/usr/bin/perl

# This file is part of Koha.
#
# Parts Copyright (C) 2015 Nicolas Legrand
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


use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Auth;    # get_template_and_user
use C4::Output;
use C4::NewsChannels;    # GetNewsToDisplay
use C4::Languages qw(getTranslatedLanguages accept_language);
use C4::Koha qw( GetDailyQuote );
use C4::Items;
use C4::Biblio;
use C4::Items;
use C4::Context;
use C4::Dates;
use C4::Reserves;

my $input = new CGI;
my $dbh   = C4::Context->dbh;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "circ/iwantthis.tt",
        type            => "intranet",
	flagsrequired   => { circulate => 'circulate_remaining_permissions' },
        query           => $input,
        authnotrequired => ( 0 ),
    }
);

my $homebranch;
my $borrower;

my $findborrower = $input->param('findborrower');
if ($findborrower) {
    $borrower = C4::Members::GetMember( cardnumber => $findborrower );
    if ( $borrower ) {
	$template->param(
	    borrowernumber => $borrower->{'borrowernumber'},
	    cardnumber     => $borrower->{'cardnumber'},
	    firstname      => $borrower->{'firstname'},
	    surname        => $borrower->{'surname'},
	    branchcode     => $borrower->{'branchcode'},
	    )
    }
    $homebranch = $borrower->{'branchcode'};
}

my $itemnumber = $input->param('itemnumber');
my $biblionumber = $input->param('biblionumber');
my $item = {};
my @itemsinfo = GetItemsInfo($biblionumber);
my $canreserve = 1
    if (CanItemBeReserved( $borrower->{'borrowernumber'}, $itemnumber ) eq 'OK');
my $allalreadyreserved = 1; #Next condition search if one is available and switch this one

foreach my $candidate (@itemsinfo) {
    if ($candidate->{'itemnumber'} == $itemnumber) {
	$item = $candidate;
    }
    my @reserves = GetReservesFromItemnumber($candidate->{'itemnumber'});
   $allalreadyreserved = 0
	if (! @reserves
	    && CanItemBeReserved( $borrower->{'borrowernumber'}, $candidate->{'itemnumber'})
	    && $candidate->{'holdingbranch'} == $homebranch);
}

# my $item = GetItem($itemnumber);
#my $biblio = GetBiblio($item->{'biblionumber'});
my ($reserved, $nextreserve, $allreserves) = C4::Reserves::CheckReserves($itemnumber);
my $reservesn = ($allreserves) ? @$allreserves : 0 ;

my $selfreserve;
my $reservesbefore = 0;
my $isissued;
my $selfissue;

if (defined $allreserves) {
    foreach my $reserve (@$allreserves) {
	if ($borrower->{'borrowernumber'} == $reserve->{'borrowernumber'}
	    && $itemnumber == $reserve->{'itemnumber'}) {
	    $selfreserve = 1;
	    last;
	} elsif ($itemnumber == $reserve->{'itemnumber'}) {
	    $reservesbefore += 1;
	}
    }
}

if ($item->{'onloan'}) {
    $isissued = 1;
}

if ($item->{'borrowernumber'} eq $borrower->{'borrowernumber'}) {
    $selfissue = 1;
}

my $op = $input->param('op');
my $from = $input->param('op');

if (!$selfreserve && !$selfissue && $op eq 'reserve' && $canreserve) {
    my $rank;
    if ($allalreadyreserved && (! $item->{'enumchron'} || $item->{'ccode'} == 'REVUE')) {
	$itemnumber = undef;
	$rank = C4::Reserves::CalculatePriority($biblionumber);
    }
    elsif ($reserved) {
	$rank = C4::Reserves::CalculateItemPriority($itemnumber);
    }
    elsif ($from == 'stacks') {
	$rank = 0;
    }
    my $found;
    my $error;
    my $notes = "opac-iwantthis";
    if (!$reservesbefore && $from == 'stacks') {
	$found = 'A';
    }
    
    my $dt = DateTime->now + DateTime::Duration->new(days => C4::Context->preference('ReservesMaxPickUpDelay'));
    my $expdate = $dt->mdy('/');    
    my $resid = AddReserve(
	$homebranch, $borrower->{'borrowernumber'},
	$biblionumber, 'a', [$biblionumber],
	$rank, C4::Dates->new()->output(), $expdate,
	$notes, $item->{'title'},
	$itemnumber, $found
	);
#    if ($resid) {
	$selfreserve = 1;
#    } else {
#	$error = 'ERROR_CANT_HOLD';
#    }
}

    open my $lol, '>>','/tmp/lolilola';
    print $lol "$$ -> card: $borrower->{'cardnumber'} - $biblionumber - $itemnumber - canreserve: $canreserve - reservesbefore: $reservesbefore - selfissue: $selfissue - isissued: $isissued\n";
    close $lol;


$template->param(
    item               => $item,
    homebranch         => $homebranch,
    reservesn          => $reservesn,
    selfreserve        => $selfreserve,
    reservesbefore     => $reservesbefore,
    isissued           => $isissued,
    selfissue          => $selfissue,
    canreserve         => $canreserve,
    borroitem          => $item->{'borrowernumber'},
    borrowenv          => $borrower->{'borrowernumber'},
    biblionumber       => $biblionumber,
    itemnumber         => $itemnumber,
    allalreadyreserved => $allalreadyreserved,
    );


output_html_with_http_headers $input, $cookie, $template->output;
