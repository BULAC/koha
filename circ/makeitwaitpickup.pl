#!/usr/bin/perl

use Modern::Perl;
use CGI;
use C4::Output;
use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Items;
use C4::Biblio;
use C4::Reserves;
use C4::Circulation;
use C4::Stats;
use DateTime::Duration;

my $input = new CGI;

my ( $template, $librarian, $cookie ) =
    get_template_and_user(
	{
	    template_name   => "circ/makeitwaitpickup.tt",
	    query           => $input,
	    type            => "intranet",
	    authnotrequired => 0,
	    flagsrequired   => { circulate => 'circulate_remaining_permissions' },
	    debug           => 1,
	}
    );


my $branch = 'BULAC';
my $deskcode = C4::Context->userenv->{"deskcode"} || undef;
my $errors = {};
my $barcode = $input->param('barcode');
$barcode =~ s/^\s+//;
$barcode =~ s/\s+$//;
chomp($barcode);
my $itemnumber = GetItemnumberFromBarcode($barcode);
my $item;
if ( ! $itemnumber ) {
    $errors->{'BAD_BARCODE'} = $barcode ;
}
else {
    $item = GetItem($itemnumber);
    my $openissue = GetOpenIssue($itemnumber);
    if (! $openissue) {
	$errors->{'NOT_ONLOAN'} = $barcode ;
    }
    else {
	$errors->{'LOL'} = "LOL";
	my $biblionumber = $item->{'biblionumber'};
	my $borrowernumber = $openissue->{'borrowernumber'};
	AddReturn($barcode, $branch);
	my $canitembereserved = CanItemBeReserved( $borrowernumber, $itemnumber );
	if ($canitembereserved eq 'OK') {
	    my $found = 'W';
	    my $rank = 0;
	    my $error;
	    my $notes = "Mise de côté";
	    my $resid = AddReserve(
		$branch,
		$borrowernumber,
		$biblionumber,
		[$biblionumber],
		$rank,
		output_pref({ dt => dt_from_string, dateformat => 'iso' , dateonly => 1 }),
		'',
		$notes,
		$item->{'title'},
		$itemnumber,
		$found,
		$item->{'ccode'},
		);
	    UpdateStats (
		{
		    branch             => $branch,
		    type               => 'putaside',
		    borrowernumber     => $borrowernumber,
		    associatedborrower => $resid,
		    itemnumber         => $itemnumber,
		    itemtype           => $item->{'itype'},
		    ccode              => $item->{'ccode'},
		}
	    );
	    ModReserveAffect( $itemnumber, $borrowernumber, undef, $deskcode);
	    print $input->redirect("returns.pl?barcode=$barcode&checkwaitpickup=1");
	    exit;
	}
	else {
	    $errors->{'CANT_RESERVE'} = $borrowernumber ;
	}
    }
}

$template->param(
    item => $item,
    errors => $errors,
    );

output_html_with_http_headers $input, $cookie, $template->output;
