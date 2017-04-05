#!/usr/bin/perl

use Modern::Perl;
use CGI;
use C4::Auth;
use C4::Context;
use C4::Members;
use C4::JasperReport;

my $query=new CGI;

checkauth($query, 0, {borrowers => 1}, 'intranet');

my $mimetype='application/pdf';
my $borrower_number = $query->param('member');

if ($borrower_number) {
    GenerateReport('exports', 'carte_usager', {borrower_number => $borrower_number}, 'pdf', "/tmp/member_${borrower_number}.pdf")
}

print $query->header(
    -expires=>'now',
    -type=>$mimetype,
    -disposition=>"+inline:borrower_${borrower_number}.pdf",
    -filename=>'borrower_${borrower_number}.pdf'
    );

open my $pdf, '<', "/tmp/member_${borrower_number}.pdf"
    or die "Can't open /tmp/member_${borrower_number}.pdf: $@";
binmode $pdf;
while (<$pdf>) {
    print;
}
close $pdf;
unlink "/tmp/member_${borrower_number}.pdf";
