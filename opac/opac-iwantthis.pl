#!/usr/bin/perl

# This file is part of Koha.
#
# Parts Copyright (C) 2013  Mark Tompsett
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
        template_name   => "opac-iwantthis.tt",
        type            => "opac",
        query           => $input,
        authnotrequired => ( 1 ),
        flagsrequired   => { borrow => 1 },
    }
);

my $casAuthentication = C4::Context->preference('casAuthentication');
$template->param(
    casAuthentication   => $casAuthentication,
);

# display news
# use cookie setting for language, bug default to syspref if it's not set
my ($theme, $news_lang, $availablethemes) = C4::Templates::themelanguage(C4::Context->config('opachtdocs'),'opac-main.tt','opac',$input);

my $homebranch;
if (C4::Context->userenv) {
    $homebranch = C4::Context->userenv->{'branch'};
}

my $itemnumber = $input->param('itemnumber');
my $biblionumber = $input->param('biblionumber');
my $item = {};
foreach my $candidate (GetItemsInfo($biblionumber)) {
    if ($candidate->{'itemnumber'} == $itemnumber) {
	$item = $candidate;
	last;
    }
}

#my $item = GetItem($itemnumber);
#my $biblio = GetBiblio($item->{'biblionumber'});
my ($reserved, $nextreserve, $allreserves) = C4::Reserves::CheckReserves($itemnumber);
my $reservesn = ($allreserves) ? @$allreserves : 0 ;

my $selfreserve;
my $reservesbefore = 0;
my $selfissue;

if (defined $allreserves) {
    foreach my $reserve (@$allreserves) {
	if (C4::Context->userenv->{'number'} == $reserve->{'borrowernumber'}) {
	    $selfreserve = 1;
	    last;
	}
	$reservesbefore += 1;
    }
}

if ($item->{'borrowernumber'} eq C4::Context->userenv->{'number'}) {
    $selfissue = 1;
}

my $op = $input->param('op');
my $from = $input->param('op');
my $canreserve = 1
    if (CanItemBeReserved( C4::Context->userenv->{'number'}, $itemnumber ) eq 'OK');
if (!$selfreserve && !$selfissue and $op eq 'reserve') {
    my $found;
    my $rank = 0;
    my $error;
    my $notes = "opac-iwantthis";
    if (!$reservesbefore and $from = 'stacks') {
	$found = 'A';
    }
    my $resid = AddReserve(
	$homebranch, C4::Context->userenv->{'number'},
	$biblionumber, 'a', [$biblionumber],
	$rank, C4::Dates->new()->output(), '',
	$notes, $item->{'title'},
	$itemnumber, $found
	);
#    if ($resid) {
	$selfreserve = 1;
#    } else {
#	$error = 'ERROR_CANT_HOLD';
#    }
}

$template->param(
    item => $item,
    homebranch => $homebranch,
    reservesn => $reservesn,
    selfreserve => $selfreserve,
    reservesbefore => $reservesbefore,
    selfissue => $selfissue,
    canreserve => $canreserve,
    borroitem => $item->{'borrowernumber'},
    borrowenv => C4::Context->userenv->{'number'},
    biblionumber => $biblionumber,
    itemnumber => $itemnumber,
    );


output_html_with_http_headers $input, $cookie, $template->output;
