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
my $borrower_number = $query->param('borrowernumber');
my $itemnumber = $query->param('itemnumber');

if ($borrower_number) {
    GenerateReport('exports', 'fiche_reservation', {Item_Number => $itemnumber, borrower_number => $borrower_number}, 'pdf', "/tmp/hold_slip_${itemnumber}_${borrower_number}.pdf")
}


open my $pdf, '<', "/tmp/hold_slip_${itemnumber}_${borrower_number}.pdf"
    or die "Can't open /tmp/hold_slip_${itemnumber}_${borrower_number}.pdf: $@";
print $query->header(
    -expires=>'now',
    -type=>$mimetype,
    -disposition=>"+inline:'hold_slip_${itemnumber}_borrower_${borrower_number}.pdf",
    -filename=>'hold_slip_${itemnumber}_borrower_${borrower_number}.pdf'
    );
binmode $pdf;
while (<$pdf>) {
    print;
}
close $pdf;
unlink "/tmp/hold_slip_${itemnumber}_${borrower_number}.pdf";
