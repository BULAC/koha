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

my $input = new CGI;

my ( $template, $borrowernumber, $cookie ) =
    get_template_and_user(
	{
	    template_name   => "circ/manageholdsbarcode.tt",
	    query           => $input,
	    type            => "intranet",
	    authnotrequired => 0,
	    flagsrequired   => { circulate => 'circulate_remaining_permissions', },
	    debug           => 1,
	}
    );


my $errors = [];
my $reserve_barcode = $input->param('reserve_barcode');
if ($reserve_barcode !~ /^1230*?([1-9][0-9]+)$/) {
    push {'BAD_BARCODE' => $reserve_barcode}, @$errors;
}

my $reserve_id;
if ($reserve_barcode =~ /^1230*?([1-9][0-9]+)$/) {
    $reserve_id = $1;
} else {
    push {'BAD_RESERVE_ID' => $reserve_id },  @$errors;
}

my $reserve = GetReserve($reserve_id);

my $reserve_status;

if (not defined $reserve) {
    my $dbh = C4::Context->dbh;
    my $query = "SELECT * FROM old_reserves WHERE reserve_id = ?";
    my $sth = $dbh->prepare( $query );
    $sth->execute( $reserve_id );
    $reserve = $sth->fetchrow_hashref();
    if ($reserve) {
	$reserve_status = 'done';
    }
    else {
	$reserve_status = 'notfound';
    }
}
else {
    $reserve_status = 'active';
}

my $document;
if ($reserve) {
    my $item = GetItem($reserve->{'itemnumber'});
    my $biblio = GetBiblio($item->{'biblionumber'});
    $document = { %$biblio, %$item };
}

my $item_barcode = $input->param('item_barcode');
if (not $document->{'barcode'} and $item_barcode) {
    $document->{'barcode'} = $item_barcode;
    my $modified_fields = {};
    $modified_fields->{'barcode'} = $document->{'barcode'};
    if ($document->{'itype'} = 'DOC-TMP-MG') {
	$modified_fields->{'enumchron'} = $input->param('enumchron')
	    if ($input->param('enumchron'));
	$modified_fields->{'pubyear'} = $input->param('pubyear')
	    if ($input->param('pubyear'));
    }
    C4::Items::ModItem({'barcode' => $document->{'barcode'}}, $document->{'biblionumber'}, $document->{'itemnumber'});
}

if ($document->{'barcode'} and $reserve_status = 'active') {
    print $input->redirect("returns.pl?barcode=$document->{'barcode'}");
}

$template->param(
    reserve => $reserve,
    reserve_barcode => $reserve_barcode,
    item_barcode => $item_barcode,
    document => $document,
    reserve_status => $reserve_status,
    );

output_html_with_http_headers $input, $cookie, $template->output;
