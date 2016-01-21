#!/usr/bin/perl

use Modern::Perl;
use CGI;
use C4::Auth;
use C4::Context;
use C4::Members;
use C4::JasperReport;
use CAM::PDF;

my $query=new CGI;

checkauth($query, 0, {circulate => 1}, 'intranet');

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
eval {
    $mergepdfres = `pdftk @tmppdffiles cat output /tmp/bordereau_accompagnement-${reservesstr}.pdf`;
    open my $lol, '>', '/tmp/lol';
    print $lol $mergepdfres;
    print $lol "pdftk @tmppdffiles cat output /tmp/bordereau_accompagnement-${reservesstr}.pdf";
};
die "error: $@: $mergepdfres" if $@;

print $query->header(
    -expires=>'now',
    -type=>$mimetype,
    -disposition=>"+inline:bordereau_accompagnement-${reservesstr}.pdf",
    -filename=>'bordereau_accompagnement-borrower_${reservesstr}.pdf'
    );

open my $pdffh, '<', "/tmp/bordereau_accompagnement-${reservesstr}.pdf"
    or die "Can't open /tmp/bordereau_accompagnement-${reservesstr}.pdf: $@";
binmode $pdffh;
while (<$pdffh>) {
    print;
}
close $pdffh;


#unlink "/tmp/bordereau_accompagnement-${reserves}.pdf";
