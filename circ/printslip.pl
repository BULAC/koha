#!/usr/bin/perl

use Modern::Perl;
use CGI;
use C4::Auth;
use C4::Context;
use C4::Members;
use C4::JasperReport;
use CAM::PDF;

my $query=new CGI;

checkauth($query, 0, {circulate => "circulate_remaining_permissions"}, 'intranet');

my $mimetype='application/pdf';
my $reservesstr =  $query->param('reserves');
my @reserves = split ',', $reservesstr;

foreach my $reserve (@reserves) {
    if ($reserve) {
	GenerateReport('exports', 'bordereau_accompagnement', {request_number => $reserve}, 'pdf', "/tmp/bordereau_accompagnement-${reserve}.pdf")
    }
}

my @tmppdffiles = map { "/tmp/bordereau_accompagnement-$_.pdf" } @reserves;

my $mergepdfres;
my $timestamp = localtime();
$timestamp =~ s/ /_/g;
my $fid = $timestamp . '-' . $$ ;
eval {
    $mergepdfres = `pdftk @tmppdffiles cat output /tmp/bordereau_accompagnement-${fid}.pdf`;
};

foreach (@tmppdffiles) {
    unlink ;
}

die "error: $@: $mergepdfres" if $@;

print $query->header(
    -expires=>'now',
    -type=>$mimetype,
    -disposition=>"+inline:bordereau_accompagnement-${fid}.pdf",
    -filename=>'bordereau_accompagnement-borrower_${fid}.pdf'
    );

open my $pdffh, '<', "/tmp/bordereau_accompagnement-${fid}.pdf"
    or die "Can't open /tmp/bordereau_accompagnement-${fid}.pdf: $@";
binmode $pdffh;
while (<$pdffh>) {
    print;
}
close $pdffh;

unlink "/tmp/bordereau_accompagnement-${fid}.pdf";
